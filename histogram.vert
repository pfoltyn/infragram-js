attribute vec2 aVertexPosition;

varying vec2 vTextureCoord;
varying float vPassthrough;

uniform sampler2D uVertSampler;
uniform int uColorChannel;
uniform int uPassthrough;

void main(void)
{
    if (uPassthrough == 0)
    {
        vec4 color = texture2D(uVertSampler, aVertexPosition);
        float value = 0.0;
        if (uColorChannel == 0)
            value = color.r;
        else if (uColorChannel == 1)
            value = color.g;
        else if (uColorChannel == 2)
            value = color.b;
        else
            value = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
        gl_Position = vec4((value * 2.0) - 1.0, 0.0, 0.0, 1.0);
        gl_PointSize = 1.0;
        vPassthrough = 0.0;
    }
    else
    {
        gl_Position = vec4(aVertexPosition, 0.0, 1.0);
        vTextureCoord = (aVertexPosition + 1.0) / 2.0;
        vPassthrough = 1.0;
    }
}
