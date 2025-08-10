#==================================================#
# Install required Julia packages for the project
#==================================================#

using Pkg

if ENV["USER"] == "pohwaran"
    cd("/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost")
end

Pkg.activate("/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost")
Pkg.instantiate()

ENV["PYTHON"]="/Users/pohwaran/anaconda3/bin/python"
Pkg.build("PyCall")
