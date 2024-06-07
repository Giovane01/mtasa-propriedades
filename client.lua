local espacamentoTexto = 50
local dadosEmpresa = {}
local propriedades = {}
local markers = {}
local blips = {}

addEvent("atualizarDadosEmpresa", true)
addEventHandler("atualizarDadosEmpresa", resourceRoot, function(dadosAtualizados)
    dadosEmpresa = dadosAtualizados
end)

addEvent("receberDadosEmpresas", true)
addEventHandler("receberDadosEmpresas", resourceRoot, function(dadosRecebidos)
    propriedades = dadosRecebidos.propriedades
end)

function rgbToHex(r, g, b)
    return string.format("#%02X%02X%02X", r, g, b)
end

function desenharDadosEmpresa()
    for i, propriedade in ipairs(propriedades) do
        if not propriedade.coordenadas then
            return
        end

        local x, y, z = unpack(propriedade.coordenadas)
        local distance = getDistanceBetweenPoints3D(x, y, z, getCameraMatrix())
        if distance <= 30 then
            local screenX, screenY = getScreenFromWorldPosition(x, y, z + 0.5)
            if screenX and screenY then
                local r, g, b, alpha = unpack(propriedade.corMarker)
                local corHex = rgbToHex(r, g, b)
                local texto = corHex .. "Tipo: #FFFFFF" .. propriedade.tipo .. "\n" ..
                             corHex .. "Dono: #FFFFFF" .. propriedade.donoEmpresa .. "\n" ..
                             corHex .. "Custo: #FFFFFF$" .. propriedade.valorEmpresa .. "\n" ..
                             corHex .. "Retorno: #FFFFFF$" .. propriedade.retornoEmpresa.. " / 30min" ..
                             "\n" .. corHex .. "ID: #FFFFFF" .. i 
                local larguraTexto = dxGetTextWidth(texto, 2, "default")
                local tamanhoTexto = 1.5 - (distance / 500)
                dxDrawText(texto, screenX - larguraTexto / 5, screenY, screenX, screenY, tocolor(r, g, b, 200), tamanhoTexto, "default-bold", "left", "center", false, false, false, true)
            end
        end
    end
end
addEventHandler("onClientRender", root, desenharDadosEmpresa)
