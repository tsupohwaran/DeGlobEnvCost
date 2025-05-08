#==================================================#
# Install required Julia packages for the project
#==================================================#

using Pkg
cd("/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost")
Pkg.activate("/Users/pohwaran/Doctorate/Paper/DeGlobEnvCost")
Pkg.instantiate()

if ENV["USER"] == "pohwaran"
    ENV["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" * ENV["PATH"]
end

ENV["PYTHON"]="/Users/pohwaran/anaconda3/bin/python"
Pkg.build("PyCall")