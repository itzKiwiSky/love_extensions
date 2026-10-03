-- got from this site https://www.codeproject.com/Articles/2645/Fast-Simple-Secure-Encryption-Routine --
-- Big thanks to foxy_ayato to translate this to me lol --

local bit32 = require 'bit'

local function Crypt(inp, key)
    -- Tamanho do sbox
    local Sbox = {}
    local Sbox2 = {}

    -- Definimos uma chave padrão caso nenhuma seja fornecida
    local OurUnSecuredKey = "kiwinevida:3"
    local OurKeyLen = #OurUnSecuredKey

    local keylen = key and #key or 0
    local inplen = #inp

    -- Inicializando as tabelas
    for i = 0, 255 do
        Sbox[i] = i
    end

    local j = 0
    -- Inicializa Sbox2 com a chave do usuário, se houver, ou com a chave padrão
    for i = 0, 255 do
        if keylen > 0 then
            Sbox2[i] = string.byte(key, (i % keylen) + 1)
        else
            Sbox2[i] = string.byte(OurUnSecuredKey, (i % OurKeyLen) + 1)
        end
    end

    -- Embaralha o Sbox com base no Sbox2
    for i = 0, 255 do
        j = (j + Sbox[i] + Sbox2[i]) % 256
        Sbox[i], Sbox[j] = Sbox[j], Sbox[i]
    end

    local i, j = 0, 0
    local output = {}

    -- Criptografa/descriptografa os dados de entrada
    for x = 1, inplen do
        i = (i + 1) % 256
        j = (j + Sbox[i]) % 256

        -- Embaralha mais o Sbox
        Sbox[i], Sbox[j] = Sbox[j], Sbox[i]

        -- Gera o byte pseudo-aleatório
        local t = (Sbox[i] + Sbox[j]) % 256
        local k = Sbox[t]

        -- XOR com o dado original e armazena no resultado
        output[x] = string.char(bit32.bxor(string.byte(inp, x), k))
    end

    -- Retorna o texto criptografado/descriptografado
    return table.concat(output)
end

return Crypt
