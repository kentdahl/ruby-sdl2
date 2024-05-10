module SDL3
  # @return [String] Version string of Ruby/SDL3
  VERSION = "0.0.1"
  # @return [Array<Integer>] Version of Ruby/SDL3, [major, minor, patch level] 
  VERSION_NUMBER = VERSION.split(".").map(&:to_i)
end
