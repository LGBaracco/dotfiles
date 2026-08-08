try
    @eval using Revise
    @eval using OhMyREPL
catch e
    @warn "Error initializing Packages" e
end

# atreplinit() do repl
#     try
#     catch e
#         @warn "Error initializing OhMyREPL" e
#     end
# end
