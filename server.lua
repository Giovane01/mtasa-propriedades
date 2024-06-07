local markers = {}
local blips = {}
local lastPurchaseTime = {}

function criarBancoDados()
    if not fileExists("dados_empresas.db") then
        local dadosPadrao = {
            propriedades = {}
        }

        local file = fileCreate("dados_empresas.db")
        if file then
            fileWrite(file, toJSON(dadosPadrao))
            fileClose(file)
        end
    end
end
addEventHandler("onResourceStart", resourceRoot, criarBancoDados)

function carregarDadosEmpresas(player)
    local file = fileOpen("dados_empresas.db")
    if file then
        local dados = fileRead(file, fileGetSize(file))
        fileClose(file)
        dadosEmpresas = fromJSON(dados)
        if dadosEmpresas and dadosEmpresas.propriedades then
            for _, propriedade in ipairs(dadosEmpresas.propriedades) do
                if not propriedade.corMarker then
                    propriedade.corMarker = {255, 0, 0, 50}
                end
            end
        end
    end
    if dadosEmpresas and dadosEmpresas.propriedades then
        for _, propriedade in ipairs(dadosEmpresas.propriedades) do
            if not propriedade.tipo then
                propriedade.tipo = "N/A"
            end
        end
    end
    setTimer(function()
        triggerClientEvent(player, "receberDadosEmpresas", resourceRoot, dadosEmpresas)
    end, 500, 1)
end

function enviarDados()
    for _, player in ipairs(getElementsByType("player")) do
        carregarDadosEmpresas(player)
    end
end
addEventHandler("onResourceStart", resourceRoot, enviarDados)

function criarMarcadoresEBlips()
    for i, marker in ipairs(markers) do
        destroyElement(marker)
    end
    markers = {}

    for i, blip in ipairs(blips) do
        destroyElement(blip)
    end
    blips = {}

    for i, propriedade in ipairs(dadosEmpresas.propriedades) do
        local x, y, z = unpack(propriedade.coordenadas)
        markers[i] = createMarker(x, y, z-1, "cylinder", 1.5, unpack(propriedade.corMarker))
        local tamanhoBlip = 1
        local tipoBlip = math.random(58, 62)
        blips[i] = createBlip(x, y, z, tipoBlip, tamanhoBlip, unpack(propriedade.corBlip))
        setBlipVisibleDistance(blips[i], 300)
        addEventHandler("onMarkerHit", markers[i], function(player)
            verificarDonoEmpresa(player, i)
        end)
    end
end
addEventHandler("onResourceStart", resourceRoot, criarMarcadoresEBlips)

function salvarDadosEmpresas()
    local file = fileOpen("dados_empresas.db")
    if file then
        fileWrite(file, toJSON(dadosEmpresas))
        fileClose(file)
    end
end

function verificarDonoEmpresa(player, propriedadeIndex)
    local propriedades = dadosEmpresas.propriedades
    if not propriedades or not propriedades[propriedadeIndex] then
        outputChatBox("A propriedade que você está tentando comprar não existe.", player, 255, 0, 0)
        return
    end
    local propriedade = propriedades[propriedadeIndex]
    if propriedade.donoEmpresa == "VAZIO" then
        outputChatBox("#FFFFFFEssa propriedade está vazia, você pode comprá-la por #D70000$" .. propriedade.valorEmpresa .. "#FFFFFF digitando #D70000/comprar", player, 255, 255, 255, true)
    else
        outputChatBox("#FFFFFFDigite #D70000/comprar #FFFFFFpara adquirir de " .. propriedade.donoEmpresa .. "", player, 255, 255, 0, true)
    end
end

function comprarEmpresa(player)
    local propriedades = dadosEmpresas.propriedades
    local x, y, z = getElementPosition(player)
    local propriedadeIndex = nil
    local currentTime = getTickCount()
    local lastPurchase = lastPurchaseTime[player] or 0
    local timeSinceLastPurchase = currentTime - lastPurchase
    local minTimeBetweenPurchases = 3600000  -- Tempo mínimo entre compras (em milissegundos)

    if timeSinceLastPurchase < minTimeBetweenPurchases then
        local remainingTime = minTimeBetweenPurchases - timeSinceLastPurchase
        local remainingTimeSeconds = math.ceil(remainingTime / 1000)
        local minutes = math.floor(remainingTimeSeconds / 60)
        local seconds = remainingTimeSeconds % 60

        outputChatBox("Aguarde " .. minutes .. " minutos e " .. seconds .. " segundos antes de comprar outra propriedade.", player, 255, 0, 0)
        return
    end
    for i, propriedade in ipairs(propriedades) do
        local px, py, pz = unpack(propriedade.coordenadas)
        local distancia = getDistanceBetweenPoints3D(x, y, z, px, py, pz)
        if distancia <= 1.5 then
            propriedadeIndex = i
            break
        end
    end
    if not propriedadeIndex then
        outputChatBox("Você não está sobre uma propriedade válida.", player, 255, 0, 0)
        return
    end
    local propriedade = propriedades[propriedadeIndex]
    if not propriedade then
        outputChatBox("A propriedade que você está tentando comprar não existe.", player, 255, 0, 0)
        return
    end
    local dinheiroJogador = getPlayerMoney(player)
    if dinheiroJogador >= propriedade.valorEmpresa then
        local contaJogador = getAccountName(getPlayerAccount(player))
        if contaJogador ~= propriedade.conta then
            local antigoDono = getAccountPlayer(propriedade.conta)
            if antigoDono then
                local valorCusto = propriedade.valorEmpresa
                outputConsole("Antigo Dono: " .. getPlayerName(antigoDono))
                outputConsole("Valor do Custo: $" .. valorCusto)
                givePlayerMoney(antigoDono, valorCusto)
                outputChatBox("Você recebeu $" .. valorCusto .. " do jogador " .. getPlayerName(player) .. " pela propriedade " .. propriedade.tipo, antigoDono, 0, 255, 0)
            else
                outputConsole("Antigo Dono não encontrado.")
            end
            takePlayerMoney(player, propriedade.valorEmpresa)
            propriedade.donoEmpresa = getPlayerName(player)
            propriedade.conta = contaJogador
            salvarDadosEmpresas()
            enviarDados()
            triggerClientEvent(player, "atualizarDadosEmpresas", root, dadosEmpresas) 
            lastPurchaseTime[player] = currentTime -- Atualiza o tempo da última compra para o jogador atual
            outputChatBox("Você comprou a propriedade por $" .. propriedade.valorEmpresa, player, 0, 255, 0, true)
        else
            outputChatBox("Você já é o dono desta propriedade.", player, 255, 0, 0, true)
        end
    else
        outputChatBox("Você não tem dinheiro suficiente para comprar esta propriedade", player, 255, 0, 0, true)
    end
end
addCommandHandler("comprar", comprarEmpresa)

function resetarBancoDados(player, cmd, indice)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Console")) then
        outputChatBox("Você não tem permissão para redefinir o banco de dados.", player, 255, 0, 0)
        return
    end
    indice = tonumber(indice)
    if not indice or indice < 1 or indice > #dadosEmpresas.propriedades then
        outputChatBox("Índice inválido.", player, 255, 0, 0)
        return
    end
    table.remove(dadosEmpresas.propriedades, indice)
    for i, propriedade in ipairs(dadosEmpresas.propriedades) do
        propriedade.indice = i
    end

    salvarDadosEmpresas()
    enviarDados()

    for i, marker in ipairs(markers) do
        destroyElement(marker)
    end
    markers = {}
    for i, blip in ipairs(blips) do
        destroyElement(blip)
    end
    blips = {}

    criarMarcadoresEBlips()
    outputChatBox("Propriedade de índice " .. indice .. " removida.", root, 0, 255, 0)
end
addCommandHandler("rx", resetarBancoDados)

function criarPropriedade(player, cmd, custo, retorno, ...)
    local x, y, z = getElementPosition(player)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Console")) then
        outputChatBox("Você não tem permissão para criar uma propriedade.", player, 255, 0, 0)
        return
    end

    custo = tonumber(custo)
    retorno = tonumber(retorno)

    if not custo or not retorno or custo <= 0 or retorno <= 0 then
        outputChatBox("Sintaxe: /propriedade [CUSTO] [RETORNO] [TIPO]", player, 255, 165, 0)
        return
    end

    if custo < retorno then
        outputChatBox("Não é permitido custo menor que retorno", player, 255, 165, 0)
        return
    end

    if tipo == "" then
        outputChatBox("Sintaxe: /propriedade [CUSTO] [RETORNO] [TIPO]", player, 255, 165, 0)
        return
    end

    local corR = math.random(0, 255)
    local corG = math.random(0, 255)
    local corB = math.random(0, 255)

    local novoTipo = table.concat({...}, " ")

    local novaPropriedade = {
        coordenadas = {x, y, z},
        corMarker = {corR, corG, corB, 50},
        corBlip = {255, 0, 0, 255},
        donoEmpresa = "VAZIO",
        valorEmpresa = custo,
        retornoEmpresa = retorno,
        conta = nil,
        indice = 1,
        tipo = novoTipo
    }

    table.insert(dadosEmpresas.propriedades, novaPropriedade)
    salvarDadosEmpresas()
    criarMarcadoresEBlips()
    enviarDados()
    outputChatBox("Nova propriedade criada.", player, 0, 255, 0)
end

addCommandHandler("criarpropriedade", criarPropriedade)

function alterarCustoPropriedade(player, cmd, indice, novoCusto)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Console")) then
        outputChatBox("Você não tem permissão para alterar o custo de uma propriedade.", player, 255, 0, 0)
        return
    end

    indice = tonumber(indice)
    novoCusto = tonumber(novoCusto)

    if not indice or not novoCusto or novoCusto <= 0 then
        outputChatBox("Sintaxe: /custo [ID] [NOVO CUSTO]", player, 255, 165, 0)
        return
    end

    local propriedades = dadosEmpresas.propriedades
    if not propriedades[indice] then
        outputChatBox("A propriedade com o ID especificado não existe.", player, 255, 0, 0)
        return
    end

    propriedades[indice].valorEmpresa = novoCusto
    salvarDadosEmpresas()
    enviarDados()
    outputChatBox("O custo da propriedade com o ID " .. indice .. " foi alterado para $" .. novoCusto .. ".", player, 0, 255, 0)
end
addCommandHandler("custo", alterarCustoPropriedade)

function getAccountPlayer(accountName)
    for _, player in ipairs(getElementsByType("player")) do
        if getAccountName(getPlayerAccount(player)) == accountName then
            return player
        end
    end
    return false
end

function entregarRetorno()
    for _, propriedade in ipairs(dadosEmpresas.propriedades) do
        if propriedade.conta ~= nil and propriedade.donoEmpresa ~= "VAZIO" then
            local jogador = getAccountPlayer(propriedade.conta)
            if jogador then
                local retorno = propriedade.retornoEmpresa
                givePlayerMoney(jogador, retorno)
                outputChatBox("Você recebeu um retorno de $" .. retorno .. " pela propriedade " .. propriedade.tipo, jogador, 0, 255, 0)
            end
        end
    end    
end

setTimer(entregarRetorno, 30 * 60 * 1000, 0)

function arrumarRetornos(player, cmd)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Console")) then
        outputChatBox("Você não tem permissão.", player, 255, 0, 0)
        return
    end

    for _, propriedade in ipairs(dadosEmpresas.propriedades) do
        if propriedade.valorEmpresa then
            propriedade.retornoEmpresa = propriedade.valorEmpresa * 0.05
        else
            outputConsole("Valor da empresa não definido para a propriedade com índice " .. propriedade.indice .. ". Não foi possível calcular o retorno.")
        end
    end

    salvarDadosEmpresas()
    enviarDados()
    outputChatBox("Os retornos de todas as propriedades foram ajustados para 5% do valor do custo.", player, 0, 255, 0)
end

addCommandHandler("arrumar", arrumarRetornos)

function contarPropriedades(player, cmd)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Console")) then
        outputChatBox("Você não tem permissão.", player, 255, 0, 0)
        return
    end

    local totalPropriedades = #dadosEmpresas.propriedades
    outputChatBox("Total de propriedades: " .. totalPropriedades, player, 0, 255, 0)
end

addCommandHandler("propriedades", contarPropriedades)