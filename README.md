# GObject generator

This is a script that creates empty GObject boilerplate code, with init
and finalize functions, as well as getters/setters/interfaces.

Limitations: Writes the struct to the .h file, sets all parameter types
to gchar* and only supports a single interface to implement. But it does
create a nice starting point for the actual implementation. Also, the code
is not formatted at all, so a nice autoformatter is highly recommended.

## Arguments:
 -n Name of the new object, underscore lowercase (mandatory)
 -m Name of the module, underscore lowercase (mandatory)
 -p Parameter to add. Can have several (Optional)
 -e Extends other GObject. Must be type, ie G_TYPE_OBJECT (Optional)
 -i Implement interface. Must be type (Optional)

## Usage
````
./generateGObject.sh -n "name_of_object" -m "module_prefix" \
        -p "param1" -p "param2" -i "G_TYPE_INTEFACE" -e "G_TYPE_OBJECT"
````
