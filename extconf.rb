require 'mkmf'

def add_cflags(str)
  $CFLAGS += " " + str
end

def add_libs(str)
  $LOCAL_LIBS += " " + str
end

def run_config_program(*args)
  IO.popen([*args], "r") do |io|
    io.gets.chomp
  end
end

def config(pkg_config, header, libnames)
  if system("pkg-config", pkg_config, "--exists")
    puts("Use pkg-config #{pkg_config}")
    add_cflags(run_config_program("pkg-config", pkg_config, "--cflags"))
    add_libs(run_config_program("pkg-config", pkg_config, "--libs"))
  else
    libnames.each{|libname| break if have_library(libname) }
  end
  
  have_header(header)
end

def sdl3config_with_command
  sdl3_config = with_config('sdl2-config', 'sdl2-config') # TODO
  add_cflags(run_config_program(sdl3_config, "--cflags"))
  add_libs(run_config_program(sdl3_config, "--libs"))
end

def sdl3config_on_mingw
  have_library("mingw32")
  have_library("SDL3")
  add_libs("-mwindows")
end

case RbConfig::CONFIG["arch"]
when /mingw/
  sdl3config_on_mingw
else
  sdl3config_with_command
end

config("SDL3_image", 'SDL3_image/SDL_image.h', ["SDL3_image", "SDL_image"])
config("SDL3_mixer", 'SDL3_mixer/SDL_mixer.h', ["SDL3_mixer", "SDL_mixer"])
config("SDL3_ttf", 'SDL3_ttf/SDL_ttf.h', ["SDL3_ttf", "SDL_ttf"])
have_header('SDL3/SDL_filesystem.h')

have_const("MIX_INIT_MODPLUG", 'SDL3_mixer/SDL_mixer.h')
have_const("MIX_INIT_FLUIDSYNTH", 'SDL3_mixer/SDL_mixer.h')
have_const("MIX_INIT_MID", 'SDL3_mixer/SDL_mixer.h')
have_const("SDL_RENDERER_PRESENTVSYNC", 'SDL3/SDL_render.h')
have_const("SDL_WINDOW_HIGH_PIXEL_DENSITY", 'SDL3/SDL_video.h')
have_const("SDL_WINDOW_MOUSE_CAPTURE", 'SDL3/SDL_video.h')

create_makefile('sdl3_ext')
