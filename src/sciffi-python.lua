require("sciffi-base")

sciffi.interpretators.python = {
    execute = function(code)
        local temp_file = os.tmpname() .. ".py"
        local file = io.open(temp_file, "w")

        if not file then
            return "Error creating temporary file"
        end

        file:write(sciffi.helpers.deindent(code))
        file:close()

        -- TODO: make an interpretator executable an option
        local command = "python " .. temp_file

        local file = io.popen(command, "r")
        if not file then
            return "Error executing command"
        end

        local output = file:read("*a")
        file:close()
        sciffi.write(output)
        return nil
    end
}
