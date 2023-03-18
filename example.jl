using HelpGPT
using Term



HelpGPT.install_help_stacktrace()


function g(x)
    x + "a"
end

function f(x)
    return g(x)
end


f(1)  # this will trigger the error inside `g`