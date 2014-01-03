# This file is part of infragram-js.
#
# infragram-js is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# infragram-js is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with infragram-js.  If not, see <http://www.gnu.org/licenses/>.


modeToEquationMap = {
    "hsv":  ["#h_exp", "#s_exp", "#v_exp"],
    "rgb":  ["#r_exp", "#g_exp", "#b_exp"],
    "mono": ["#m_exp", "#m_exp", "#m_exp"],
    "raw":  ["r", "g", "b"],
    "ndvi": ["(((r-b)/(r+b))+1)/2", "(((r-b)/(r+b))+1)/2", "(((r-b)/(r+b))+1)/2"],
    "nir":  ["r", "r", "r"],
}

waitForShadersToLoad = 0
imgContext = null
mapContext = null


createBuffer = (ctx, data) ->
    gl = ctx.gl
    buffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer)
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW)
    buffer.length = data.length
    buffer.itemSize = 2
    return buffer


createTexture = (ctx, textureUnit) ->
    gl = ctx.gl
    texture = gl.createTexture()
    gl.activeTexture(textureUnit)
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, ctx.canvas.width, ctx.canvas.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    return texture


createScatterBuffer = (ctx) ->
    itemSize = 2
    scatterData = []
    xInc = 1.0 / ctx.canvas.width
    yInc = 1.0 / ctx.canvas.height
    x = 0.0
    y = 0.0
    for index in [0..(ctx.canvas.height * ctx.canvas.width * itemSize) - itemSize] by itemSize
        scatterData[index] = x
        scatterData[index + 1] = y
        x += xInc
        y += yInc
    return createBuffer(ctx, scatterData)


createContext = (mode, greyscale, colormap, slider, canvasName) ->
    ctx = new Object()
    ctx.mode = mode
    ctx.greyscale = greyscale
    ctx.colormap = colormap
    ctx.slider = slider
    ctx.updateShader = true
    ctx.canvas = document.getElementById(canvasName)
    ctx.canvas.addEventListener("webglcontextlost", ((event) -> event.preventDefault()), false)
    ctx.canvas.addEventListener("webglcontextrestored", glRestoreContext, false)
    ctx.gl = getWebGLContext(ctx.canvas)
    if ctx.gl
        ctx.scatterBuffer = createScatterBuffer(ctx)
        ctx.gl.getExtension("OES_texture_float")
        ctx.vertexBuffer = createBuffer(ctx, [-1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0])
        ctx.framebuffer = ctx.gl.createFramebuffer()
        ctx.imageTexture = createTexture(ctx, ctx.gl.TEXTURE0)
        ctx.cdfTexture = createTexture(ctx, ctx.gl.TEXTURE1)
        ctx.histoTexture = createTexture(ctx, ctx.gl.TEXTURE2)
        ctx.outputTexture = createTexture(ctx, ctx.gl.TEXTURE3)
        return ctx
    else
        return null


drawScene = (ctx, returnImage) ->
    gl = ctx.gl

    if !returnImage
        requestAnimFrame(() -> drawScene(ctx, false))

    if ctx.histogram
        gl.viewport(0, 0, 256, 1)
        gl.bindFramebuffer(gl.FRAMEBUFFER, ctx.framebuffer)
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, ctx.histoTexture, 0)
        gl.clear(gl.COLOR_BUFFER_BIT)
        gl.useProgram(ctx.histoProgram)

        gl.uniform1i(ctx.histoProgram.pVertSampler, 0)
        gl.uniform1i(ctx.histoProgram.pColorChannel, 3)
        gl.uniform1i(ctx.histoProgram.pPassthrough, 0)

        gl.bindBuffer(gl.ARRAY_BUFFER, ctx.scatterBuffer)
        gl.enableVertexAttribArray(ctx.histoProgram.pVertexPosition)
        gl.vertexAttribPointer(ctx.histoProgram.pVertexPosition, ctx.scatterBuffer.itemSize, gl.FLOAT, false, 0, 0)

        gl.blendFunc(gl.ONE, gl.ONE)
        gl.enable(gl.BLEND)
        gl.drawArrays(gl.POINTS, 0, ctx.scatterBuffer.length / ctx.scatterBuffer.itemSize)
        gl.disable(gl.BLEND)

        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, ctx.outputTexture, 0)
        gl.uniform1i(ctx.histoProgram.pFragSampler, 2)
        gl.uniform1i(ctx.histoProgram.pPassthrough, 1)
        gl.bindBuffer(gl.ARRAY_BUFFER, ctx.vertexBuffer)
        gl.enableVertexAttribArray(ctx.histoProgram.pVertexPosition)
        gl.vertexAttribPointer(ctx.histoProgram.pVertexPosition, ctx.vertexBuffer.itemSize, gl.FLOAT, false, 0, 0)
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, ctx.vertexBuffer.length / ctx.vertexBuffer.itemSize)

        pixels = new Uint8Array(256 * 4)
        gl.activeTexture(gl.TEXTURE3)
        gl.readPixels(0, 0, 256, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixels)
        pixels = new Float32Array(pixels.buffer)

    if ctx.updateShader
        ctx.updateShader = false

        ctx.shaderProgram = generateShader(ctx)
        gl.useProgram(ctx.shaderProgram)

        ctx.shaderProgram.pVertexPosition = gl.getAttribLocation(ctx.shaderProgram, "aVertexPosition")
        ctx.shaderProgram.pSampler = gl.getUniformLocation(ctx.shaderProgram, "uSampler")
        ctx.shaderProgram.pCdfSampler = gl.getUniformLocation(ctx.shaderProgram, "uCdfSampler")
        ctx.shaderProgram.pSliderUniform = gl.getUniformLocation(ctx.shaderProgram, "uSlider")
        ctx.shaderProgram.pNdviUniform = gl.getUniformLocation(ctx.shaderProgram, "uNdvi")
        ctx.shaderProgram.pGreyscaleUniform = gl.getUniformLocation(ctx.shaderProgram, "uGreyscale")
        ctx.shaderProgram.pHsvUniform = gl.getUniformLocation(ctx.shaderProgram, "uHsv")
        ctx.shaderProgram.pColormap = gl.getUniformLocation(ctx.shaderProgram, "uColormap")

    gl.viewport(0, 0, ctx.canvas.width, ctx.canvas.height)
    gl.bindFramebuffer(gl.FRAMEBUFFER, null)
    gl.useProgram(ctx.shaderProgram)

    gl.bindBuffer(gl.ARRAY_BUFFER, ctx.vertexBuffer)
    gl.enableVertexAttribArray(ctx.shaderProgram.pVertexPosition)
    gl.vertexAttribPointer(ctx.shaderProgram.pVertexPosition, ctx.vertexBuffer.itemSize, gl.FLOAT, false, 0, 0)

    gl.uniform1i(ctx.shaderProgram.pSampler, 0)
    gl.uniform1i(ctx.shaderProgram.pCdfSampler, 1)
    gl.uniform1f(ctx.shaderProgram.pSliderUniform, ctx.slider)
    gl.uniform1i(ctx.shaderProgram.pNdviUniform, (if ctx.mode == "ndvi" || ctx.colormap then 1 else 0))
    gl.uniform1i(ctx.shaderProgram.pGreyscaleUniform, (if ctx.greyscale then 1 else 0))
    gl.uniform1i(ctx.shaderProgram.pHsvUniform, (if ctx.mode == "hsv" then 1 else 0))
    gl.uniform1i(ctx.shaderProgram.pColormap, (if ctx.colormap then 1 else 0))

    gl.drawArrays(gl.TRIANGLE_STRIP, 0, ctx.vertexBuffer.length / ctx.vertexBuffer.itemSize)

    if returnImage
        return ctx.canvas.toDataURL("image/png")


generateShader = (ctx) ->
    [r, g, b] = modeToEquationMap[ctx.mode]
    r = if r.charAt(0) == "#" then $(r).val() else r
    g = if g.charAt(0) == "#" then $(g).val() else g
    b = if b.charAt(0) == "#" then $(b).val() else b

    # Map HSV to shader variable names
    r = r.toLowerCase().replace(/h/g, "r").replace(/s/g, "g").replace(/v/g, "b")
    g = g.toLowerCase().replace(/h/g, "r").replace(/s/g, "g").replace(/v/g, "b")
    b = b.toLowerCase().replace(/h/g, "r").replace(/s/g, "g").replace(/v/g, "b")

    # Sanitize strings
    r = r.replace(/[^xrgb\/\-\+\*\(\)\.0-9]*/g, "")
    g = g.replace(/[^xrgb\/\-\+\*\(\)\.0-9]*/g, "")
    b = b.replace(/[^xrgb\/\-\+\*\(\)\.0-9]*/g, "")

    # Convert int to float
    r = r.replace(/([0-9])([^\.])?/g, "$1.0$2")
    g = g.replace(/([0-9])([^\.])?/g, "$1.0$2")
    b = b.replace(/([0-9])([^\.])?/g, "$1.0$2")

    r = "r" if r == ""
    g = "g" if g == ""
    b = "b" if b == ""

    code = $("#shader-fs-template").html()
    code = code.replace(/@1@/g, r)
    code = code.replace(/@2@/g, g)
    code = code.replace(/@3@/g, b)
    $("#shader-fs").html(code)

    return createProgramFromScripts(ctx.gl, ["shader-vs", "shader-fs"])


glSetMode = (ctx, newMode) ->
    ctx.mode = newMode
    ctx.updateShader = true
    $("#download").show()
    if ctx.mode == "ndvi"
        $("#colorbar-container")[0].style.display = "inline-block"
        $("#colormaps-group")[0].style.display = "inline-block"
    else
        $("#colorbar-container")[0].style.display = "none"
        $("#colormaps-group")[0].style.display = "none"


calculateCdf = (img) ->
    canvas = document.createElement("canvas")
    canvas.width = img.width
    canvas.height = img.height
    context = canvas.getContext("2d")
    context.drawImage(img, 0, 0, canvas.width, canvas.height)
    imgData = context.getImageData(0, 0, canvas.width, canvas.height)

    bins = new Float32Array(256 * 3)
    for i in [0..imgData.data.length - 1] by 4
        bins[(256 * 0) + imgData.data[i + 0]]++
        bins[(256 * 1) + imgData.data[i + 1]]++
        bins[(256 * 2) + imgData.data[i + 2]]++

    max = img.width * img.height
    cdfs = new Float32Array(256 * 4)
    cdfs[0] = bins[256 * 0] / max
    cdfs[1] = bins[256 * 1] / max
    cdfs[2] = bins[256 * 2] / max
    for i in [4..(256 * 4) - 1] by 4
        cdfs[i + 0] = cdfs[i - 4 + 0] + (bins[(256 * 0) + (i / 4)] / max)
        cdfs[i + 1] = cdfs[i - 4 + 1] + (bins[(256 * 1) + (i / 4)] / max)
        cdfs[i + 2] = cdfs[i - 4 + 2] + (bins[(256 * 2) + (i / 4)] / max)

    return cdfs


glHandleOnLoadTexture = (ctx, imageData) ->
    gl = ctx.gl
    texImage = new Image()
    texImage.onload = (event) ->
        gl.activeTexture(gl.TEXTURE0)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, event.target)
        gl.activeTexture(gl.TEXTURE1)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 256, 1, 0, gl.RGBA, gl.FLOAT, calculateCdf(this))
        gl.activeTexture(gl.TEXTURE2)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 256, 1, 0, gl.RGBA, gl.FLOAT, null)
        gl.activeTexture(gl.TEXTURE3)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 256, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, null)
    texImage.src = imageData


glShaderLoaded = () ->
    waitForShadersToLoad--
    if !waitForShadersToLoad
        ctx = imgContext
        ctx.histogram = true
        ctx.histoProgram = createProgramFromScripts(ctx.gl, ["histo-vs", "histo-fs"])
        ctx.histoProgram.pVertexPosition = ctx.gl.getAttribLocation(ctx.histoProgram, "aVertexPosition")
        ctx.histoProgram.pVertSampler = ctx.gl.getUniformLocation(ctx.histoProgram, "uVertSampler")
        ctx.histoProgram.pFragSampler = ctx.gl.getUniformLocation(ctx.histoProgram, "uFragSampler")
        ctx.histoProgram.pColorChannel = ctx.gl.getUniformLocation(ctx.histoProgram, "uColorChannel")
        ctx.histoProgram.pPassthrough = ctx.gl.getUniformLocation(ctx.histoProgram, "uPassthrough")

        drawScene(imgContext)
        drawScene(mapContext)


glInitInfragram = () ->
    imgContext = createContext("raw", true, false, 1.0, "image")
    mapContext = createContext("raw", true, true, 1.0, "colorbar")
    waitForShadersToLoad = 4
    $("#shader-vs").load("shader.vert", glShaderLoaded)
    $("#shader-fs-template").load("shader.frag", glShaderLoaded)
    $("#histo-vs").load("histogram.vert", glShaderLoaded)
    $("#histo-fs").load("histogram.frag", glShaderLoaded)
    return if imgContext && mapContext then true else false


glRestoreContext = () ->
    imageData = imgContext.imageData
    imgContext = createContext(
        imgContext.mode, imgContext.greyscale, imgContext.colormap, imgContext.slider, "image")
    mapContext = createContext(
        mapContext.mode, mapContext.greyscale, mapContext.colormap, mapContext.slider, "colorbar")
    if imgContext && mapContext
        glHandleOnLoadTexture(imgContext, imageData)


glHandleOnChangeFile = (files) ->
    if files && files[0]
        reader = new FileReader()
        reader.onload = (eventObject) ->
            imgContext.imageData = eventObject.target.result
            glHandleOnLoadTexture(imgContext, eventObject.target.result)
        reader.readAsDataURL(files[0])


glUpdateImage = (video) ->
    gl = imgContext.gl
    gl.activeTexture(gl.TEXTURE0)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, video)


glHandleOnClickDownload = () ->
    # create an "off-screen" anchor tag
    lnk = document.createElement("a")
    # the key here is to set the download attribute of the a tag
    lnk.download = (new Date()).toISOString().replace(/:/g, "_") + ".png"
    lnk.href = drawScene(imgContext, true)

    # create a "fake" click-event to trigger the download
    if document.createEvent
        event = document.createEvent("MouseEvents")
        event.initMouseEvent(
            "click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null)
        lnk.dispatchEvent(event)
    else if lnk.fireEvent
        lnk.fireEvent("onclick")


glHandleOnClickRaw        = ()      -> glSetMode(imgContext, "raw")
glHandleOnClickNdvi       = ()      -> glSetMode(imgContext, "ndvi")
glHandleOnSubmitInfraHsv  = ()      -> glSetMode(imgContext, "hsv")
glHandleOnSubmitInfra     = ()      -> glSetMode(imgContext, "rgb")
glHandleOnSubmitInfraMono = ()      -> glSetMode(imgContext, "mono")
glHandleOnClickGrey       = ()      -> imgContext.greyscale = mapContext.greyscale = true
glHandleOnClickColor      = ()      -> imgContext.greyscale = mapContext.greyscale = false
glHandleOnSlide           = (event) -> imgContext.slider = event.value / 100.0
