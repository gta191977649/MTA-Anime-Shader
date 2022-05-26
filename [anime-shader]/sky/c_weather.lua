Weather = {
    hours = { 0, 5, 6, 7, 12, 17, 18, 22,24},
    data = {
        [0] = {
            ["SKY"] = {21,47,85,42,74,120}, --  Skytop RGB,SkyBottom RGB
            ["CLOUD"] = {45,102,155,64,129,178,67,137,185}, -- Shadow Color,Highlight Color,Rim Color,
        },
        [5] = {
            ["SKY"] = {25,63,98,91,106,150},
            ["CLOUD"] = {48,92,144,85,117,151,166,139,145},
        },
        [6] = {
            ["SKY"] = {55,137,188,255,253,130},
            ["CLOUD"] = {176,173,189,224,197,187,255,234,195},
        },
        [7] = {
            ["SKY"] = {30,118,201,84,171,211},
            ["CLOUD"] = {141,203,235,212,239,252,227,247,255},
        },
        [12] = {
            ["SKY"] = {49,99,153,111,188,244},
            ["CLOUD"] = {163,230,255,230,243,252,255,255,255},
        },
        [12] = {
            ["SKY"] = {49,99,153,111,188,244},
            ["CLOUD"] = {181,230,255,212,238,252,255,255,255},
        },
        [17] = {
            ["SKY"] = {37,99,175,128,191,224},
            ["CLOUD"] = {198,211,243,247,251,249,255,255,255},
        },
        [18] = {
            ["SKY"] = {171,112,125,255,181,152},
            ["CLOUD"] = {170,110,121,223,138,112,224,141,110},
        },
        [22] = {
            ["SKY"] = {22,48,86,48,82,132},
            ["CLOUD"] = {36,88,145,58,121,170,72,141,186},
        },
  
    }
}

function interpolateRGB(r1,g1,b1,r2,g2,b2,fa,fb) 
    local r = fa * r1 + fb * r2
    local g = fa * g1 + fb * g2
    local b = fa * b1 + fb * b2
    return r,g,b
end


function renderWeather(shaderTable) 
    
    --setSkyGradient(36,117,189,152,213,252)
	setColorFilter (0, 0, 0, 0, 0, 0, 0, 0)
    --resetColorFilter()
    local h,m = getTime()
    local time = h+m/60.0;

    

    local currentIndex = 1

    while(time >= Weather.hours[currentIndex+1]) do 
        currentIndex = currentIndex + 1
    end

    local h = Weather.hours[currentIndex]
    local next = currentIndex + 1 >= #Weather.hours and 0 or Weather.hours[currentIndex + 1]

    local data = Weather.data
    
    --local interp = time % 1
    local interp = (time - h) / (next - h)
    print(interp)

    -- start liner interpration
    -- sky gradient
    local tr,tg,tb = interpolateRGB(data[h].SKY[1],data[h].SKY[2],data[h].SKY[3],data[next].SKY[1],data[next].SKY[2],data[next].SKY[3],1-interp,interp)
    local br,bg,bb = interpolateRGB(data[h].SKY[4],data[h].SKY[5],data[h].SKY[6],data[next].SKY[4],data[next].SKY[5],data[next].SKY[6],1-interp,interp)
    setSkyGradient(tr,tg,tb,br,bg,bb)
    
    -- cloud color
    local sr,sg,sb = interpolateRGB(data[h].CLOUD[1],data[h].CLOUD[2],data[h].CLOUD[3],data[next].CLOUD[1],data[next].CLOUD[2],data[next].CLOUD[3],1-interp,interp)
    local hr,hg,hb = interpolateRGB(data[h].CLOUD[4],data[h].CLOUD[5],data[h].CLOUD[6],data[next].CLOUD[4],data[next].CLOUD[5],data[next].CLOUD[6],1-interp,interp)
    local rh,rg,rb = interpolateRGB(data[h].CLOUD[7],data[h].CLOUD[8],data[h].CLOUD[9],data[next].CLOUD[7],data[next].CLOUD[8],data[next].CLOUD[9],1-interp,interp)
    dxSetShaderValue ( shaderTable.skyboxTropos, "shadowColor", {sr/255,sg/255,sb/255,1})
    dxSetShaderValue ( shaderTable.skyboxTropos, "highlightColor", {hr/255,hg/255,hb/255,1})
    dxSetShaderValue ( shaderTable.skyboxTropos, "edgeLightColor", {rh/255,rg/255,rb/255,1})
    

    dxSetShaderValue ( shaderTable.skyboxTropos, "cloudFade",0 )

    
end