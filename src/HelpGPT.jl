module HelpGPT

import OpenAI
import Markdown 
import Term.TermMarkdown: parse_md
import Term: tprint, default_stacktrace_width
import Term: Panel, hLine, RenderableText
import Term.Errors: render_backtrace, StacktraceContext
import Term: highlight, reshape_code_string
import Term.Style: apply_style

using Preferences

const api_key_name = "OPENAI_API_KEY"
const api_pref_name = "openai_api_key"

"""
    function getAPIkey()

Returns an OpenAI API key to use from either the `LocalPreferences.toml` file or the
`OPENAI_API_KEY` environment variable. If neither is present, returns `missing`.
"""
function getAPIkey()
    key = missing

    # try to load key from Preferences:
    key = @load_preference(api_pref_name, missing)

    # if not koaded from preferences, look in environment variables
    if ismissing(key) && haskey(ENV, api_key_name)
        key = ENV[api_key_name]
    end

    return key
end

"""
    function setAPIkey(key::String)

Sets the OpenAI API key for ReplGPT to use. The key will be saved as plaintext to your environment's
`LocalPreferences.toml` file (perhaps somewhere like `~/.julia/environments/v1.8/LocalPreferences.toml`).
The key can be deleted with `ReplGPT.clearAPIkeyI()`. 
"""
function setAPIkey(key::String)
    @set_preferences!(api_pref_name => key)
end

"""
    function clearAPIkey()

Deletes the OpenAI API key saved in `LocalPreferences.toml` if present. 

See also: ReplGPT.setAPIkey(key::String)
"""
function clearAPIkey()
    @delete_preferences!(api_pref_name)
end



function ask(io, s)
    key = getAPIkey()
    w = default_stacktrace_width() - 12
    conversation = Vector{Dict{String,String}}()
    out = if !ismissing(key)
        userMessage = Dict("role" => "user", "content" => s)
        push!(conversation, userMessage)

        r = OpenAI.create_chat(key, "gpt-3.5-turbo", conversation)
        response = r.response["choices"][begin]["message"]["content"]

        Panel(
                RenderableText(parse_md(Markdown.parse(response); width=w-12); style="white on_#20232a", background="on_#20232a"); 
                title="AI help",
                title_style="white",
                width=w, 
                background="on_#20232a",
                subtitle="Help", subtitle_style="white", padding=(4, 4, 1, 1), 
                subtitle_justify=:right,
                style = "white on_#20232a"
        ) / hLine(; style="dim")
        
    else
        parse_md(
            "OpenAI API key not found! Please set with `ReplGPT.setAPIkey(\"<YOUR OPENAI API KEY>\")` or set the environment variable $(api_key_name)=<YOUR OPENAI API KEY>",
        )
    end

    tprint(io, out)
end



# ---------------------------------------------------------------------------- #
#                              INSTALL STACKTRACE                              #
# ---------------------------------------------------------------------------- #

"""
    install_term_stacktrace(; reverse_backtrace::Bool = true, max_n_frames::Int = 30)
Replace the default Julia stacktrace error stacktrace printing with Term's.
Term parses a `StackTrace` adding additional info and style before printing it out to the user.
The printed output consists of two parts:
    - a list of "frames": nested code points showing where the error occurred, the "Error Stack"
    - a message: generally the standard info message given by Julia but with addintional formatting
        option. 
Several options are provided to reverse the order in which the frames are shown (compared to
Julia's default ordering), hide extra frames when a large number is in the trace (e.g. Stack Overflow error)
and hide Base and standard libraries error information (i.e. when a frame is in a module belonging to those.)
"""
function install_help_stacktrace(;
    reverse_backtrace::Bool = true,
    max_n_frames::Int = 30,
    hide_frames = true,
)
    @eval begin
        function Base.showerror(io::IO, er, bt; backtrace = true)
            print(io, "\n")
            
            # @info "Showing" er bt

            # shorten very long backtraces
            isa(er, StackOverflowError) && (bt = [bt[1:25]..., bt[(end - 25):end]...])

            # if the terminal is too narrow, avoid using Term's functionality
            if default_stacktrace_width() < 70
                println(io)
                @warn "Term.jl: can't render error message, console too narrow. Using default stacktrace"
                Base.show_backtrace(io, bt)
                print(io, '\n'^3)
                Base.showerror(io, er)
                return
            end

            try
                # create a StacktraceContext
                ctx = StacktraceContext()

                # print an hLine with the error name
                ename = string(typeof(er))
                length(bt) > 0 && print(
                    io,
                    hLine(
                        ctx.out_w,
                        "{default bold $(ctx.theme.err_errmsg)}$ename{/default bold $(ctx.theme.err_errmsg)}";
                        style = "dim $(ctx.theme.err_errmsg)",
                    ),
                )

                # print error backtrace or panel
                bt_str = if length(bt) > 0
                    rendered_bt = render_backtrace(
                        ctx,
                        bt;
                        reverse_backtrace = $(reverse_backtrace),
                        max_n_frames = $(max_n_frames),
                        hide_frames = $(hide_frames),
                    )
                    print(io, rendered_bt)
                    sprint(Base.show_backtrace, bt)
                else
                    nothing
                end

                # print message panel if VSCode is not handling that through a second call to this fn

                msg = highlight(sprint(Base.showerror, er)) |> apply_style
                err_panel = Panel(
                    RenderableText(
                        reshape_code_string(msg, ctx.module_line_w);
                        width = ctx.module_line_w,
                    );
                    width = ctx.out_w,
                    title = "{bold $(ctx.theme.err_errmsg) default underline}$(typeof(er)){/bold $(ctx.theme.err_errmsg) default underline}",
                    padding = (2, 2, 1, 1),
                    style = "dim $(ctx.theme.err_errmsg)",
                    title_justify = :center,
                    fit = false,
                )
                print(io, err_panel)


                # now ask ChatGPT for help
                # ask_msg = "I've got this error in my code: \n\n```\n$msg\n```\n\nWhat should I do? Please provide a possible fix."
                # isnothing(bt_str) || (ask_msg *= "\n\nHere's the stacktrace:\n\n```\n$bt_str\n```")

                ask_msg = "I've got this error in my code: \n\n```\n$msg\n```\n\nPlease summarize the error, where it happens and why. Then suggests ways to fix it."
                isnothing(bt_str) || (ask_msg *= "\n\nHere's the stacktrace:\n\n```\n$bt_str\n```")
                ask(io, ask_msg)

            catch cought_err  # catch when something goes wrong during error handling in Term
                println(io, "pipi")
                @error "Term.jl: error while rendering error message: " cought_err

                for (i, (exc, _bt)) in enumerate(current_exceptions())
                    i == 1 && println("Error during term's stacktrace generation:")
                    Base.show_backtrace(io, _bt)
                    print(io, '\n'^3)
                    Base.showerror(io, exc)
                end

                print(io, '\n'^5)
                println(io, "Original error:")
                Base.show_backtrace(io, bt)
                print(io, '\n'^3)
                Base.showerror(io, er)
            end
        end
    end
end

end # module
