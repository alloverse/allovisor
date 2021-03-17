if type(jit) ~= 'table' or lovr.getOS() == 'Android' then return false end -- Added from original

local ffi = require 'ffi'
local C = ffi.os == 'Windows' and ffi.load('glfw3') or ffi.C

ffi.cdef [[
  typedef struct GLFWwindow GLFWwindow;
  typedef void (* GLFWdropfun)(GLFWwindow*,int,const char*[]);

  GLFWwindow* glfwGetCurrentContext(void);
  GLFWdropfun glfwSetDropCallback(GLFWwindow* window, GLFWdropfun callback);
]]

local window = C.glfwGetCurrentContext()

local dragndrop = {}

C.glfwSetDropCallback(window, function(window, numPaths, cPaths)
  for i=0, numPaths-1 do
    local path = ffi.string(cPaths[i])
    lovr.event.push("filedrop", path)
  end
end)

return dragndrop
