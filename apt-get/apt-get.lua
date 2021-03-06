-- pastebin get m102eGTL apt-get
-- wget https://raw.github.com/Arqade/cc-apt-get/master/apt-get/apt-get.lua apt/apt-get
--
-- Help
-- apt-get 
-- -setup (the first time)
-- -install <package>
-- -list
-- -update
-- -upgrade

srcFile = "apt/source.list"
packFile = "apt/packages"
packList = "apt/installed"

function wget(url, file)
    local result = http.get(url)

    if result then
        local content = result.readAll()
        result.close()
        local file = fs.open(file, "w")
        file.write(content)
        file.close()
    else
        print("URL download failed")
    end
end
    

function checkFile(name)
    if not fs.exists(name) then
        print("Package file does not exist. Run apt-get update")
        error()
    end
end

function checkPackfile()
    checkFile(packFile)
end

function checkPacklist()
    checkFile(packList)
end 

function pastebin(key, name)
    if fs.exists(name) then
        fs.delete(name)
    end

    shell.run("pastebin", "get", key, name)
end

function tryRead(file)
    local line = file.readLine()

    return line
end


function readPackage(file) 
    local pack = {}
    pack.name = tryRead(file)
    if pack.name == nil then 
        return nil
    end
    pack.description = tryRead(file)
    if pack.description == nil then 
        return nil
    end
    pack.key = tryRead(file)
    if pack.key == nil then 
        return nil
    end
    pack.directory = tryRead(file)
    if pack.directory == nil then 
        return nil
    end
    pack.alias = tryRead(file)
    if pack.alias == nil then 
        return nil
    end

    return pack
end

function writePackage(file, package)
    file.writeLine(package.name)
    file.writeLine(package.description)
    file.writeLine(package.key)
    file.writeLine(package.directory)
    file.writeLine(package.alias)
end

function setup()
    -- First time setup

    -- Create apt if not exists
    if not fs.exists("apt") then
        fs.makeDir("apt")
    end

    local defaultApt
    local mode
    -- Choosing mode
    while mode ~= "p" and mode ~= "u" do
        print("Downloading from pastebin [p] or github/url [u]")
        mode = read()
    end

    -- Setting defaults
    if mode == "p" then
        defaultApt = "Vt0v208y"
    else
        defaultApt = "https://raw.github.com/Arqade/cc-apt-get/master/apt-get/source.list"
    end

    print("The apt/source.list is using the default settings, please edit if necessary")

    -- Removing old configuration
    if fs.exists(srcFile) then
        fs.delete(srcFile)
    end

    -- Writing new file
    local src = fs.open(srcFile, "w")
    src.writeLine(mode .. " " .. defaultApt)
    src.close()

    -- Creating empty packages files
    p = fs.open(packList, "w")
    p.close()

end

function update()
    -- Update packages
    if not fs.exists(srcFile) then
        print("apt/source.list does not exist! Abording.")
        error()
    end

    local source = fs.open(srcFile, "r")
    local packKey = source.readLine()


    -- Read the installed packages list
    token = string.gmatch(packKey, "[^%s]+")
    if token() == "p" then
        pastebin(token(), packFile)
    else 
        wget(token(), packFile)
    end

    source.close()
end

function list() 
    checkPackfile()
    pack = fs.open(packFile, "r")

    local EOF = false
    local i = 1
    while not EOF do
        package = readPackage(pack)
        if package == nil then
            EOF = true
        else
            print("Package: " .. package.name)
            print("Description: " .. package.description)
        end
        if i % 2 == 0 then
            read()
        end

        i = i + 1
    end

    print(i .. " packages listed")
end

function upgrade()
    checkPackfile()
    pack = fs.open(packList, "r")

    local package = {}

    local EOF = false

    while not EOF do
        package = readPackage(pack)
        if package == nil then
            EOF = true
        else
            -- Upgrade it
            local mode = "none"
            for token in string.gmatch(package.key, "[^%s]+") do
                -- Uprading (can't be v)
                -- If first token, mode is unset
                if mode == "p" then
                    print("Upgrading package " .. package.name)
                    pastebin(token, package.directory .. "/" ..package.name)
                elseif mode == "u" then
                    print("Upgrading package " .. package.name)
                    wget(token, package.directory .. "/" ..package.name)
                end
                
                -- Mode checking (first token)
                if token == "p" then
                    mode = "p" 
                elseif token == "u" then 
                    mode = "u"
                end
            end
            -- check for missing Alias
            print("Resetting package " .. package.name)
            shell.setAlias(package.alias, package.directory .. "/" .. package.name)
        end
    end
    pack.close()
end

function install(lookingFor)
    --TODO: is package already installed

    checkPackfile()
    pack = fs.open(packFile, "r")

    local package = {}

    local found = false
    local EOF = false

    while not found and not EOF do
        package = readPackage(pack)
        if package == nil then
            EOF = true
        elseif package.name == lookingFor then
            found = true
        end
    end
    pack.close()

    local mode = "none"
    if found then
        for token in string.gmatch(package.key, "[^%s]+") do
            -- Installing (not for first iteration)
            if mode == "v" then
                -- Virtual package : install all following tokens
                install(token)
            elseif mode == "p" or mode == "u" then
                -- Install it
                print("Selecting previously deselected package " .. package.name)
                checkPacklist()
                list = fs.open(packList, "a")
                writePackage(list, package)
                list.close()

                -- Generating required directory
                if not fs.exists(package.directory) then
                    print ("Creating " .. package.directory)
                    fs.makeDir(package.directory)
                end

                -- Download
                if mode == "p" then
                    pastebin(token, package.directory .. "/" ..package.name)
                elseif mode == "u" then
                    wget(token,  package.directory .. "/" ..package.name)
                end

                -- Alias
                print("Setting up package " .. package.name)
                shell.setAlias(package.alias, package.directory .. "/" .. package.name)
            elseif mode ~= "none" then
                print("Wrong mode!!")
            end

            -- If token is a mode, update the mode variable
            if token == "v" then
                mode = "v"
            elseif token == "p" then
                mode = "p" 
            elseif token == "u" then 
                mode = "u"
            end
        end
    else
        print("Package " .. lookingFor .. " not found")
    end
end

local args = { ... }

if args[1] == "update" then
    update()
elseif args[1] == "list" then
    list()
elseif args[1] == "install" then
    for i = 2, #args do
        install(args[i])
    end
elseif args[1] == "remove" then
    print("Unimplemented")
elseif args[1] == "upgrade" then
    upgrade()
elseif args[1] == "setup" then
    setup()
    update()
    -- Install package apt-get
    install("apt-get")
else
    print("Argument unknown")
end
