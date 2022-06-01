technique simple
{
    pass P0
    {
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = 4;
		DepthBias = 0.000001;
		SlopeScaleDepthBias = 2;
    }
}