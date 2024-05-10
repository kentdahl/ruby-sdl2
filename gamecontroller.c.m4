/* -*- mode: C -*- */
#include "rubysdl2_internal.h"
#include <SDL3/SDL_gamepad.h>

static VALUE cGameController;
static VALUE mAxis;
static VALUE mButton;

typedef struct GameController {
    SDL_Gamepad* controller;
} GameController;

static void GameController_free(GameController* g)
{
    if (rubysdl2_is_active() && g->controller)
        SDL_CloseGamepad(g->controller);
    free(g);
}

/*
 * Document-class: SDL2::GameController
 *
 * This class represents a "Game Controller".
 *
 * In SDL2, there is a gamecontroller framework to
 * hide the details of joystick types. This framework
 * is built on the existing joystick API.
 * 
 * The framework consists of two parts:
 *
 * * Mapping joysticks to game controllers
 * * Aquire input from game controllers
 *
 * Mapping information is a string, and described as:
 *
 *    GUID,name,mapping
 *
 * GUID is a unique ID of a type of joystick and
 * given by {Joystick#GUID}. name is the human readable
 * string for the device, and mappings are contorller mappings
 * to joystick ones.
 * 
 * This mappings abstract the details of joysticks, for exmaple,
 * the number of buttons, the number of axes, and the position
 * of these buttons a on pad.
 * You can use unified interface 
 * with this framework theoretically.
 * Howerver, we need to prepare the
 * database of many joysticks that users will use. A database
 * is available at https://github.com/gabomdq/SDL_GameControllerDB,
 * but perhaps this is not sufficient for your usage.
 * In fact, Steam prepares its own database for Steam games,
 * so if you will create a game for Steam, this framework is
 * useful. Otherwise, it is a better way to use joystick API
 * directly.
 *
 * @!method destroy?
 *   Return true if the gamecontroller is already closed.
 */

static VALUE GameController_new(SDL_Gamepad* controller)
{
    GameController* g = ALLOC(GameController);
    g->controller = controller;
    return Data_Wrap_Struct(cGameController, 0, GameController_free, g);
}

DEFINE_WRAPPER(SDL_Gamepad, GameController, controller, cGameController,
               "SDL2::GameController");


/*
 * @overload add_mapping(string)
 *
 *   Add suuport for controolers that SDL is unaware of or to cause an
 *   existing controller to have a different binding.
 *
 *   "GUID,name,mapping", where GUID is
 *   the string value from SDL_GetJoystickGUIDString(), name is the human
 *   readable string for the device and mappings are controller mappings to
 *   joystick ones. Under Windows there is a reserved GUID of "xinput" that
 *   covers all XInput devices. The mapping format for joystick is:
 * 
 *   * bX:   a joystick button, index X
 *   * hX.Y: hat X with value Y
 *   * aX:   axis X of the joystick
 *
 *   Buttons can be used as a controller axes and vice versa.
 *
 *   This string shows an example of a valid mapping for a controller:
 *   "341a3608000000000000504944564944,Afterglow PS3 Controller,a:b1,b:b2,y:b3,x:b0,start:b9,guide:b12,back:b8,dpup:h0.1,dpleft:h0.8,dpdown:h0.4,dpright:h0.2,leftshoulder:b4,,rightshoulder:b5,leftstick:b10,rightstick:b11,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:b6,righttrigger:b7"
 *   
 *   @param string [String] mapping string
 *   @return [Integer] 1 if a new mapping, 0 if an existing mapping is updated.
 */
static VALUE GameController_s_add_mapping(VALUE self, VALUE string)
{
    int ret = HANDLE_ERROR(SDL_AddGamepadMapping(StringValueCStr(string)));
    return INT2NUM(ret);
}

/*
 * @overload axis_name_of(axis)
 *
 *   Get a string representing **axis**.
 *
 *   @param axis [Integer] axis constant in {Axis}
 *   @return [String]
 */
static VALUE GameController_s_axis_name_of(VALUE self, VALUE axis)
{
    const char* name = SDL_GetGamepadStringForAxis(NUM2INT(axis));
    if (!name) {
        SDL_SetError("Unknown axis %d", NUM2INT(axis));
        SDL_ERROR();
    }
    return utf8str_new_cstr(name);
}

/*
 * @overload button_name_of(button)
 *
 *   Get a string representing **button**.
 *
 *   @param button [Integer] button constant in {Button}
 *   @return [String]
 */
static VALUE GameController_s_button_name_of(VALUE self, VALUE button)
{
    const char* name = SDL_GetGamepadStringForButton(NUM2INT(button));
    if (!name) {
        SDL_SetError("Unknown axis %d", NUM2INT(button));
        SDL_ERROR();
    }
    return utf8str_new_cstr(name);
}

/*
 * @overload axis_from_name(name)
 *
 *   Get a integer representation of the axis
 *   whose string representation is **name**.
 *
 *   The return value is the value of one of the constants in {Axis}
 *
 *   @param name [String] a string representing an axis
 *   @return [Integer]
 */
static VALUE GameController_s_axis_from_name(VALUE self, VALUE name)
{
    int axis = SDL_GetGamepadAxisFromString(StringValueCStr(name));
    if (axis < 0) {
        SDL_SetError("Unknown axis name \"%s\"", StringValueCStr(name));
        SDL_ERROR();
    } 
    return INT2FIX(axis);
}

/*
 * @overload button_from_name(name)
 *
 *   Get a integer representation of the button
 *   whose string representation is **name**.
 *
 *   The return value is the value of one of the constants in {Button}
 *
 *   @param name [String] a string representing a button
 *   @return [Integer]
 */
static VALUE GameController_s_button_from_name(VALUE self, VALUE name)
{
    int button = SDL_GetGamepadButtonFromString(StringValueCStr(name));
    if (button < 0) {
        SDL_SetError("Unknown button name \"%s\"", StringValueCStr(name));
        SDL_ERROR();
    }
    return INT2FIX(button);
}

/*
 * Get the implementation dependent name for the game controllers
 * connected to the machine.
 * 
 * The number of elements of returning array is same as
 * {Joystick.num_connected_joysticks}.
 * 
 * @return [Array<String,nil>]
 */
static VALUE GameController_s_device_names(VALUE self)
{
    int num_joysticks = SDL_NumJoysticks();
    int i;
    VALUE device_names = rb_ary_new2(num_joysticks);
    for (i=0; i<num_joysticks; ++i) {
        const char* name = SDL_GameControllerNameForIndex(i);
        if (name)
            rb_ary_push(device_names, utf8str_new_cstr(name));
        else
            rb_ary_push(device_names, Qnil);
    }
    return device_names;
}

/*
 * @overload mapping_for(guid_string)
 *   Get the game controller mapping string for a given GUID.
 *   
 *   @param guid_string [String] GUID string
 *   
 *   @return [String] 
 */
static VALUE GameController_s_mapping_for(VALUE self, VALUE guid_string)
{
    SDL_JoystickGUID guid = SDL_GetJoystickGUIDFromString(StringValueCStr(guid_string));
    return utf8str_new_cstr(SDL_GetGamepadMappingForGUID(guid));
}

/*
 * @overload open(index) 
 *   Open a game controller and return the opened GameController object.
 *   
 *   @param index [Integer] device index, up to the return value of {Joystick.num_connected_joysticks}.
 *   @return [SDL2::GameController]
 *   
 *   @raise [SDL2::Error] raised when device open is failed.
 *     For exmaple, **index** is out of range.
 */
static VALUE GameController_s_open(VALUE self, VALUE index)
{
    SDL_Gamepad* controller = SDL_OpenGamepad(NUM2INT(index));
    if (!controller)
        SDL_ERROR();
    return GameController_new(controller);
}

/*
 * Get the name of an opened game controller.
 *
 * @return [String]
 */
static VALUE GameController_name(VALUE self)
{
    const char* name = SDL_GetGamepadName(Get_SDL_GameController(self));
    if (!name)
        SDL_ERROR();

    return utf8str_new_cstr(name);
}

/*
 * Return true if **self** is opened and attached.
 */
static VALUE GameController_attached_p(VALUE self)
{
    return INT2BOOL(SDL_GamepadConnected(Get_SDL_GameController(self)));
}

/*
 * Close the game controller.
 * 
 * @return nil
 */
static VALUE GameController_destroy(VALUE self)
{
    GameController* g = Get_GameController(self);
    if (g->controller)
        SDL_CloseGamepad(g->controller);
    g->controller = NULL;
    return Qnil;
}

/*
 * Get the mapping string of **self**.
 *
 * @return [String]
 * @see .add_mapping
 * @see .mapping_for
 */
static VALUE GameController_mapping(VALUE self)
{
    return utf8str_new_cstr(SDL_GetGamepadMapping(Get_SDL_GameController(self)));
}

/*
 * @overload axis(axis)
 *   Get the state of an axis control.
 *   
 *   The state is an integer from -32768 to 32767. 
 *   The state of trigger never returns negative value (from 0 to 32767).
 *   
 *   @param axis [Integer] the index of an axis, one of the constants in {Axis}
 *   @return [Integer]
 */
static VALUE GameController_axis(VALUE self, VALUE axis)
{
    return INT2FIX(SDL_GetGamepadAxis(Get_SDL_GameController(self),
                                             NUM2INT(axis)));
}

/*
 * @overload button_pressed?(button) 
 *   Return true if a button is pressed.
 *   
 *   @param button [Integer] the index of a button, one of the constants in {Button}
 *   @return [Boolean]
 */
static VALUE GameController_button_pressed_p(VALUE self, VALUE button)
{
    return INT2BOOL(SDL_GetGamepadButton(Get_SDL_GameController(self),
                                                NUM2INT(button)));
}

/*
 * Document-module: SDL2::GameController::Axis
 *
 * This module provides constants of gamecontroller's axis indices used by
 * {SDL2::GameController} class.
 */

/*
 * Document-module: SDL2::GameController::Button
 *
 * This module provides constants of gamecontroller's button indices used by
 * {SDL2::GameController} class.
 */
void rubysdl2_init_gamecontorller(void)
{
    cGameController = rb_define_class_under(mSDL2, "GameController", rb_cObject);

    rb_define_singleton_method(cGameController, "add_mapping",
                               GameController_s_add_mapping, 1);
    rb_define_singleton_method(cGameController, "device_names",
                               GameController_s_device_names, 0);
    rb_define_singleton_method(cGameController, "axis_name_of",
                               GameController_s_axis_name_of, 1);
    rb_define_singleton_method(cGameController, "button_name_of",
                               GameController_s_button_name_of, 1);
    rb_define_singleton_method(cGameController, "mapping_for",
                               GameController_s_mapping_for, 1);
    rb_define_singleton_method(cGameController, "button_from_name",
                               GameController_s_button_from_name, 1);
    rb_define_singleton_method(cGameController, "axis_from_name",
                               GameController_s_axis_from_name, 1);
    rb_define_singleton_method(cGameController, "open", GameController_s_open, 1);
    rb_define_method(cGameController, "destroy?", GameController_destroy_p, 0);
    rb_define_method(cGameController, "destroy", GameController_destroy, 0);
    rb_define_method(cGameController, "name", GameController_name, 0);
    rb_define_method(cGameController, "attached?", GameController_attached_p, 0);
    rb_define_method(cGameController, "mapping", GameController_mapping, 0);
    rb_define_method(cGameController, "axis", GameController_axis, 1);
    rb_define_method(cGameController, "button_pressed?", GameController_button_pressed_p, 1);

    mAxis = rb_define_module_under(cGameController, "Axis");
    mButton = rb_define_module_under(cGameController, "Button");

    /* define(`DEFINE_CONTROLLER_AXIS_CONST',`rb_define_const(mAxis, "$1", INT2NUM(SDL_CONTROLLER_AXIS_$1))') */
    /* @return [Integer] index for invalid axis*/
    DEFINE_CONTROLLER_AXIS_CONST(INVALID);
    /* @return [Integer] index for Left X axis */
    DEFINE_CONTROLLER_AXIS_CONST(LEFTX);
    /* @return [Integer] index for Left Y axis */
    DEFINE_CONTROLLER_AXIS_CONST(LEFTY);
    /* @return [Integer] index for Right X axis */
    DEFINE_CONTROLLER_AXIS_CONST(RIGHTX);
    /* @return [Integer] index for Right Y axis */
    DEFINE_CONTROLLER_AXIS_CONST(RIGHTY);
    /* @return [Integer] index for Left trigger axis */
    DEFINE_CONTROLLER_AXIS_CONST(TRIGGERLEFT);
    /* @return [Integer] index for Right trigger axis */
    DEFINE_CONTROLLER_AXIS_CONST(TRIGGERRIGHT);
    /* @return [Integer] the max value of axis indices */
    DEFINE_CONTROLLER_AXIS_CONST(MAX);

    /* define(`DEFINE_CONTROLLER_BUTTON_CONST',`rb_define_const(mButton, "$1", INT2NUM(SDL_CONTROLLER_BUTTON_$1))') */
    /* @return [Integer] index for Invalid button */
    DEFINE_CONTROLLER_BUTTON_CONST(INVALID);
    /* @return [Integer] index for Button A */
    DEFINE_CONTROLLER_BUTTON_CONST(A);
    /* @return [Integer] index for Button B */
    DEFINE_CONTROLLER_BUTTON_CONST(B);
    /* @return [Integer] index for Button X */
    DEFINE_CONTROLLER_BUTTON_CONST(X);
    /* @return [Integer] index for Button Y */
    DEFINE_CONTROLLER_BUTTON_CONST(Y);
    /* @return [Integer] index for Back Button */
    DEFINE_CONTROLLER_BUTTON_CONST(BACK);
    /* @return [Integer] index for Guide Button */
    DEFINE_CONTROLLER_BUTTON_CONST(GUIDE);
    /* @return [Integer] index for Start Button */
    DEFINE_CONTROLLER_BUTTON_CONST(START);
    /* @return [Integer] index for Left stick Button */
    DEFINE_CONTROLLER_BUTTON_CONST(LEFTSTICK);
    /* @return [Integer] index for Right stick Button */
    DEFINE_CONTROLLER_BUTTON_CONST(RIGHTSTICK);
    /* @return [Integer] index for Left shoulder Button */
    DEFINE_CONTROLLER_BUTTON_CONST(LEFTSHOULDER);
    /* @return [Integer] index for Right shoulder Button */
    DEFINE_CONTROLLER_BUTTON_CONST(RIGHTSHOULDER);
    /* @return [Integer] index for D-pad UP Button */
    DEFINE_CONTROLLER_BUTTON_CONST(DPAD_UP);
    /* @return [Integer] index for D-pad DOWN Button */
    DEFINE_CONTROLLER_BUTTON_CONST(DPAD_DOWN);
    /* @return [Integer] index for D-pad LEFT Button */
    DEFINE_CONTROLLER_BUTTON_CONST(DPAD_LEFT);
    /* @return [Integer] index for D-pad RIGHT Button */
    DEFINE_CONTROLLER_BUTTON_CONST(DPAD_RIGHT);
    /* @return [Integer] The max value of button indices */
    DEFINE_CONTROLLER_BUTTON_CONST(MAX);
}
