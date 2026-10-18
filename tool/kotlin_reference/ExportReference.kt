package dev.mttmcknn.seaglass.internal

// Parity exporter. It runs the ORIGINAL sea-glass geometry sources (copied
// unchanged into src/orig) and the original SeaGlassBodyShader through Skia
// (skiko 0.9.37.4, the version Compose 1.10.3 ships). The mask rasterizer and
// shader binding mirror composeMaskRasterizer and SkiaMaterialShader with the
// Compose wrappers replaced by direct Skia calls.

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import org.jetbrains.skia.Bitmap
import org.jetbrains.skia.ColorAlphaType
import org.jetbrains.skia.ColorSpace
import org.jetbrains.skia.ColorType
import org.jetbrains.skia.FilterTileMode
import org.jetbrains.skia.GradientStyle
import org.jetbrains.skia.ImageFilter
import org.jetbrains.skia.Rect
import org.jetbrains.skia.Shader
import kotlin.math.roundToInt
import org.jetbrains.skia.Image
import org.jetbrains.skia.ImageInfo
import org.jetbrains.skia.Matrix33
import org.jetbrains.skia.Paint
import org.jetbrains.skia.Path
import org.jetbrains.skia.RuntimeEffect
import org.jetbrains.skia.RuntimeShaderBuilder
import org.jetbrains.skia.SamplingMode
import org.jetbrains.skia.Surface

private fun skiaPath(segments: List<ContourSegment>, scale: Double) = Path().apply {
    moveTo((segments[0].start.x * scale).toFloat(), (segments[0].start.y * scale).toFloat())
    for (s in segments) cubicTo(
        (s.control1.x * scale).toFloat(), (s.control1.y * scale).toFloat(),
        (s.control2.x * scale).toFloat(), (s.control2.y * scale).toFloat(),
        (s.end.x * scale).toFloat(), (s.end.y * scale).toFloat(),
    )
    closePath()
}

private fun rgbaSurface(w: Int, h: Int) =
    Surface.makeRaster(ImageInfo(w, h, ColorType.RGBA_8888, ColorAlphaType.PREMUL, ColorSpace.sRGB))

private fun pixels(surface: Surface, w: Int, h: Int): ByteArray {
    val bitmap = Bitmap()
    bitmap.allocPixels(ImageInfo(w, h, ColorType.RGBA_8888, ColorAlphaType.PREMUL, ColorSpace.sRGB))
    check(surface.readPixels(bitmap, 0, 0))
    return checkNotNull(bitmap.readPixels())
}

/** composeMaskRasterizer: white source-over on transparent, alpha bytes. */
internal val skiaMaskRasterizer: MaskRasterizer = { segments, width, height, scale, offsetX, offsetY ->
    val surface = rgbaSurface(width, height)
    surface.canvas.translate(offsetX.toFloat(), offsetY.toFloat())
    surface.canvas.drawPath(skiaPath(segments, scale), Paint().apply { color = -1; isAntiAlias = true })
    val rgba = pixels(surface, width, height)
    ByteArray(width * height) { rgba[it * 4 + 3] }
}

private fun f16Image(t: NativeFloatTexture): Image {
    val bytes = ByteArray(t.rgba.size * 2)
    for (i in t.rgba.indices) {
        val bits = float16Bits(t.rgba[i])
        bytes[i * 2] = bits.toByte()
        bytes[i * 2 + 1] = (bits ushr 8).toByte()
    }
    return Image.makeRaster(ImageInfo(t.width, t.height, ColorType.RGBA_F16, ColorAlphaType.OPAQUE), bytes, t.width * 8)
}

private fun floats(values: FloatArray): ByteArray =
    ByteBuffer.allocate(values.size * 4).order(ByteOrder.LITTLE_ENDIAN).apply { values.forEach { putFloat(it) } }.array()

internal data class Case(val id: String, val w: Double, val h: Double, val shape: RenderShape, val settings: RenderSettings, val palette: RenderPalette)

fun main(args: Array<String>) {
    val out = File(args[0]).apply { mkdirs() }
    val effect = RuntimeEffect.makeForShader(SeaGlassBodyShader)
    val lagoon = RenderPalette(0xB5D0EB, 0xD6E9FF, 0x2F647C)
    val mint = RenderPalette(0xC0DED0, 0xE6FFF0, 0x396C5A)
    val lilac = RenderPalette(0xE1CDE8, 0xFBE8F7, 0x71388B)
    val amber = RenderPalette(0xF0D9BE, 0xFFFCE0, 0x865733)
    val cases = listOf(
        Case("lagoon-rounded", 270.0, 88.0, RenderShape.Rounded, RenderSettings(seed = 33), lagoon),
        Case("mint-disc", 64.0, 64.0, RenderShape.Disc,
            RenderSettings(frost = .72, grain = .68, tumble = .055, thickness = 9.0, bulge = .80, elevation = 7.0, transmission = .48, seed = 12), mint),
        Case("lilac-capsule", 180.0, 52.0, RenderShape.Capsule,
            RenderSettings(frost = .38, grain = .23, tumble = .065, thickness = 3.0, bulge = .38, elevation = 4.0, transmission = .66, light = 45.0, seed = 7), lilac),
        Case("amber-portrait", 120.0, 200.0, RenderShape.Rounded, RenderSettings(tumble = .012, light = 200.0, seed = -3), amber),
        Case("lagoon-large", 720.0, 480.0, RenderShape.Rounded, RenderSettings(seed = 5), lagoon),
    )
    val index = StringBuilder("[\n")
    for ((n, c) in cases.withIndex()) {
        val s = c.settings.normalized()
        val fieldScale = min(1.0, sqrt(262_144.0 / (c.w * c.h)))
        val g = makeLiveMaterialGeometry(c.w, c.h, c.shape, s.tumble, s.seed, skiaMaskRasterizer, fieldScale)
        val dir = File(out, c.id).apply { mkdirs() }
        // Mask exactly as makeGeometryField requests it.
        val tw = g.geometryA.width
        val th = g.geometryA.height
        val mask = skiaMaskRasterizer(g.segments, tw + 2, th + 2, g.fieldScale.toDouble(), 1.0, 1.0)
        File(dir, "mask.u8").writeBytes(mask)
        File(dir, "a.f32").writeBytes(floats(g.geometryA.rgba))
        File(dir, "b.f32").writeBytes(floats(g.geometryB.rgba))
        // Body: SkiaMaterialShader at density 1 (one pixel per dp).
        val builder = RuntimeShaderBuilder(effect)
        val sampling = SamplingMode.LINEAR
        builder.child("geometryA", f16Image(g.geometryA).makeShader(FilterTileMode.CLAMP, FilterTileMode.CLAMP, sampling, null))
        builder.child("geometryB", f16Image(g.geometryB).makeShader(FilterTileMode.CLAMP, FilterTileMode.CLAMP, sampling, null))
        val theta = s.light * PI / 180.0
        val lx = sin(theta)
        val ly = -cos(theta)
        val lightZ = 0.52
        val lightSide = sqrt(1.0 - lightZ * lightZ)
        val halfX = lx * lightSide
        val halfY = ly * lightSide
        val halfZ = lightZ + 1.0
        val halfLength = sqrt(halfX * halfX + halfY * halfY + halfZ * halfZ)
        builder.uniform("lightDirection", floatArrayOf(lx.toFloat(), ly.toFloat()))
        builder.uniform("halfway", floatArrayOf((halfX / halfLength).toFloat(), (halfY / halfLength).toFloat(), (halfZ / halfLength).toFloat()))
        builder.uniform("materialSize", floatArrayOf(c.w.toFloat(), c.h.toFloat()))
        builder.uniform("fieldScale", floatArrayOf(g.fieldScale))
        builder.uniform("density", floatArrayOf(1f))
        builder.uniform("gradientScales", g.gradientScales)
        builder.uniform("recipeA", floatArrayOf(s.frost.toFloat(), s.grain.toFloat(), s.thickness.toFloat(), s.bulge.toFloat()))
        builder.uniform("recipeB", floatArrayOf(s.light.toFloat(), s.transmission.toFloat(), SeededRandom(s.seed).nextDouble().toFloat(), 0f))
        builder.uniform("bodyColor", rgbComponents(c.palette.body).map { it / 255f }.toFloatArray())
        builder.uniform("edgeColor", rgbComponents(c.palette.edge).map { it / 255f }.toFloatArray())
        val pw = ceil(c.w).toInt()
        val ph = ceil(c.h).toInt()
        val surface = rgbaSurface(pw, ph)
        surface.canvas.drawPath(skiaPath(g.segments, 1.0), Paint().apply { shader = builder.makeShader(); isAntiAlias = true })
        File(dir, "body.rgba").writeBytes(pixels(surface, pw, ph))
        File(dir, "ground.rgba").writeBytes(renderGround(c, g.segments))
        if (c.id == "lagoon-rounded" || c.id == "mint-disc") {
            for ((degrees, tinted) in GROUND_VARIANTS) {
                val name = "ground-${degrees.toInt()}" + (if (tinted) "-tinted" else "") + ".rgba"
                File(dir, name).writeBytes(renderGroundExtended(c, g.segments, degrees, tinted))
            }
        }
        val shapeName = c.shape.name.lowercase()
        index.append("""  {"id":"${c.id}","width":${c.w},"height":${c.h},"shape":"$shapeName",""")
            .append(""""frost":${s.frost},"grain":${s.grain},"tumble":${s.tumble},"thickness":${s.thickness},"bulge":${s.bulge},"elevation":${s.elevation},"light":${s.light},"transmission":${s.transmission},"seed":${s.seed},""")
            .append(""""body":${c.palette.body},"edge":${c.palette.edge},""")
            .append(""""fieldScale":${g.fieldScale},"textureWidth":$tw,"textureHeight":$th,"gradientScaleA":${g.gradientScales[0]},"gradientScaleB":${g.gradientScales[1]},"pixelWidth":$pw,"pixelHeight":$ph}""")
            .append(if (n < cases.lastIndex) ",\n" else "\n")
        println("exported ${c.id}: texture ${tw}x$th fieldScale=${g.fieldScale}")
    }
    File(out, "cases.json").writeText(index.append("]\n").toString())
}

/**
 * RealtimeGround at density 1: the same layer formulas (copied verbatim), each
 * path drawn into its own layer that is then blurred with Gaussian sigma
 * sigmaDp and Decal tiling (what Compose BlurEffect resolves to on Skia after
 * RealtimeGround's radius inversion). Output covers the 48 dp padding.
 */
internal fun renderGround(c: Case, segments: List<ContourSegment>): ByteArray {
    val settings = c.settings.normalized()
    val palette = c.palette
    val widthDp = c.w
    val heightDp = c.h
    val pad = MATERIAL_PADDING_DP.toFloat()
    val pw = ceil(widthDp + MATERIAL_PADDING_DP * 2.0).toInt()
    val ph = ceil(heightDp + MATERIAL_PADDING_DP * 2.0).toInt()
    val surface = rgbaSurface(pw, ph)
    val canvas = surface.canvas
    val path = skiaPath(segments, 1.0)
    val short = min(widthDp, heightDp)
    val transmission = settings.transmission
    fun layer(offsetDp: Double, sigmaDp: Double, paint: Paint) {
        val layerPaint = Paint().apply { imageFilter = ImageFilter.makeBlur(sigmaDp.toFloat(), sigmaDp.toFloat(), FilterTileMode.DECAL) }
        canvas.saveLayer(Rect.makeWH(pw.toFloat(), ph.toFloat()), layerPaint)
        canvas.translate(pad, pad + offsetDp.toFloat())
        canvas.drawPath(path, paint.apply { isAntiAlias = true })
        canvas.restore()
    }
    fun argb(alpha: Float, rgb: Int) = ((alpha * 255f).roundToInt() shl 24) or rgb
    layer(
        offsetDp = min(16.0, settings.thickness * 0.40 + settings.elevation * 0.72 + settings.bulge * short * 0.03),
        sigmaDp = min(6.0, 2.5 + settings.elevation * 0.18 + settings.frost * 0.7 + settings.bulge * short * 0.018),
        paint = Paint().apply { color = argb(((0.18 + settings.elevation * 0.001) * (1.0 - transmission * 0.82)).toFloat(), 0x3F4342) },
    )
    layer(
        offsetDp = min(8.0, settings.thickness * 0.32 + 0.8),
        sigmaDp = 1.4 + settings.elevation * 0.065,
        paint = Paint().apply { color = argb((0.10 * (1.0 - transmission * 0.70)).toFloat(), 0x3D413F) },
    )
    if (transmission > 0.001) {
        val travel = 4.0 + settings.elevation * 0.56 + short * 0.055
        fun tint(channel: Int): Int = (255.0 - (255 - channel) * 1.35).roundToInt().coerceIn(0, 255)
        val tintRgb = (tint((palette.body ushr 16) and 255) shl 16) or
            (tint((palette.body ushr 8) and 255) shl 8) or tint(palette.body and 255)
        val gradient = Shader.makeLinearGradient(
            0f, 0f, 0f, heightDp.toFloat(),
            intArrayOf(argb(0f, tintRgb), argb((transmission * 0.06).toFloat(), tintRgb),
                argb((transmission * 0.48).toFloat(), tintRgb), argb((transmission * 0.94).toFloat(), tintRgb)),
            floatArrayOf(0f, 0.45f, 0.75f, 1f),
            GradientStyle.DEFAULT,
        )
        layer(
            offsetDp = min(22.0, settings.thickness * 0.42 + travel),
            sigmaDp = min(8.0, 2.8 + short * 0.033 + settings.frost * 1.6),
            paint = Paint().apply { shader = gradient },
        )
    }
    return pixels(surface, pw, ph)
}

/** Extension variants exported for the Flutter port: (shadowDegrees, tinted). */
internal val GROUND_VARIANTS = listOf(
    90.0 to false, 135.0 to false, 0.0 to false, 270.0 to false, 180.0 to true, 135.0 to true,
)

/** Unit vector for a ground-light direction (180 = down), axis values snapped. */
internal fun shadowVector(degrees: Double): Pair<Double, Double> {
    val theta = degrees * PI / 180.0
    fun snap(v: Double) = if (kotlin.math.abs(v) < 1e-9) 0.0 else if (kotlin.math.abs(v - kotlin.math.sign(v)) < 1e-9) kotlin.math.sign(v) else v
    return snap(sin(theta)) to snap(-cos(theta))
}

/**
 * The Flutter port's extension, applied to the original RealtimeGround code
 * path above (same layers, offsets, sigmas, alphas and Skia blur):
 *  - every layer offset runs along shadowVector(shadowDegrees) instead of +y;
 *  - the transmission ramp runs along that direction across the unit box,
 *    scaled to the body (for 180 this is the original top-to-bottom ramp);
 *  - tinted: the cast and contact shadows use the body pigment at 40%
 *    brightness instead of the neutral 0x3F4342 / 0x3D413F.
 */
internal fun renderGroundExtended(c: Case, segments: List<ContourSegment>, shadowDegrees: Double, tinted: Boolean): ByteArray {
    val settings = c.settings.normalized()
    val palette = c.palette
    val widthDp = c.w
    val heightDp = c.h
    val pad = MATERIAL_PADDING_DP.toFloat()
    val pw = ceil(widthDp + MATERIAL_PADDING_DP * 2.0).toInt()
    val ph = ceil(heightDp + MATERIAL_PADDING_DP * 2.0).toInt()
    val surface = rgbaSurface(pw, ph)
    val canvas = surface.canvas
    val path = skiaPath(segments, 1.0)
    val short = min(widthDp, heightDp)
    val transmission = settings.transmission
    val (dx, dy) = shadowVector(shadowDegrees)
    fun layer(offsetDp: Double, sigmaDp: Double, paint: Paint) {
        val layerPaint = Paint().apply { imageFilter = ImageFilter.makeBlur(sigmaDp.toFloat(), sigmaDp.toFloat(), FilterTileMode.DECAL) }
        canvas.saveLayer(Rect.makeWH(pw.toFloat(), ph.toFloat()), layerPaint)
        canvas.translate(pad, pad)
        canvas.translate((dx * offsetDp).toFloat(), (dy * offsetDp).toFloat())
        canvas.drawPath(path, paint.apply { isAntiAlias = true })
        canvas.restore()
    }
    fun argb(alpha: Float, rgb: Int) = ((alpha * 255f).roundToInt() shl 24) or rgb
    fun shadowRgb(neutral: Int): Int {
        if (!tinted) return neutral
        fun dim(channel: Int) = (channel * 0.4).roundToInt().coerceIn(0, 255)
        return (dim((palette.body ushr 16) and 255) shl 16) or (dim((palette.body ushr 8) and 255) shl 8) or dim(palette.body and 255)
    }
    layer(
        offsetDp = min(16.0, settings.thickness * 0.40 + settings.elevation * 0.72 + settings.bulge * short * 0.03),
        sigmaDp = min(6.0, 2.5 + settings.elevation * 0.18 + settings.frost * 0.7 + settings.bulge * short * 0.018),
        paint = Paint().apply { color = argb(((0.18 + settings.elevation * 0.001) * (1.0 - transmission * 0.82)).toFloat(), shadowRgb(0x3F4342)) },
    )
    layer(
        offsetDp = min(8.0, settings.thickness * 0.32 + 0.8),
        sigmaDp = 1.4 + settings.elevation * 0.065,
        paint = Paint().apply { color = argb((0.10 * (1.0 - transmission * 0.70)).toFloat(), shadowRgb(0x3D413F)) },
    )
    if (transmission > 0.001) {
        val travel = 4.0 + settings.elevation * 0.56 + short * 0.055
        fun tint(channel: Int): Int = (255.0 - (255 - channel) * 1.35).roundToInt().coerceIn(0, 255)
        val tintRgb = (tint((palette.body ushr 16) and 255) shl 16) or
            (tint((palette.body ushr 8) and 255) shl 8) or tint(palette.body and 255)
        val extent = kotlin.math.abs(dx) + kotlin.math.abs(dy)
        val gradient = Shader.makeLinearGradient(
            (0.5 - dx * 0.5 * extent).toFloat(), (0.5 - dy * 0.5 * extent).toFloat(),
            (0.5 + dx * 0.5 * extent).toFloat(), (0.5 + dy * 0.5 * extent).toFloat(),
            intArrayOf(argb(0f, tintRgb), argb((transmission * 0.06).toFloat(), tintRgb),
                argb((transmission * 0.48).toFloat(), tintRgb), argb((transmission * 0.94).toFloat(), tintRgb)),
            floatArrayOf(0f, 0.45f, 0.75f, 1f),
            GradientStyle(FilterTileMode.CLAMP, false, Matrix33.makeScale(widthDp.toFloat(), heightDp.toFloat())),
        )
        layer(
            offsetDp = min(22.0, settings.thickness * 0.42 + travel),
            sigmaDp = min(8.0, 2.8 + short * 0.033 + settings.frost * 1.6),
            paint = Paint().apply { shader = gradient },
        )
    }
    return pixels(surface, pw, ph)
}
