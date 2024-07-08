#!/bin/bash

# This is a script that creates empty GObject boilerplate code, with init
# and finalize functions, as well as getters/setters/interfaces.

# Limitations: Writes the struct to the .h file, sets all parameter types
# to gchar* and only supports a single interface to implement. But it does
# create a nice starting point for the actual implementation. Also, the code
# is not formatted at all, so a nice autoformatter is highly recommended.

# Arguments:
# -n Name of the new object, underscore lowercase (mandatory)
# -m Name of the module, underscore lowercase (mandatory)
# -p Parameter to add. Can have several (Optional)
# -e Extends other GObject. Must be type, ie G_TYPE_OBJECT (Optional)
# -i Implement interface. Must be type (Optional)


# Usage: ./generateGObject.sh -n "name_of_object" -m "module_prefix" \
#        -p "param1" -p "param2" -i "G_TYPE_INTEFACE" -e "G_TYPE_OBJECT"

MODULE="" #ui
NAME="" #object_example
FULL_NAME="" #ui_object_example
CAMEL_NAME="" #UiObjectExample
TYPE="" # UI_TYPE_OBJECT_EXAMPLE
CAST="" # UI_OBJECT_EXAMPLE

EXTENDS="" #GObject
EXTENDS_TYPE="" # G_TYPE_OBJECT
PROPENUM=""
PROPLIST=""
PUBLIC_PROPS=""
PROP_FREE=""
PROPS=()
SET_PROPERTY=""
GET_PROPERTY=""
PROP_INIT=""
PROP_ARGLIST=""
PROP_NEW_OBJ_ARGS=""
SIGS=()
SIG_ARRAY=""

type_to_camel () {
	local PARTS=$(echo ${1,,} | tr "_" "\n")
	local CAMEL_NAME=""

	for p in $PARTS; 	do
	    if [[ "$p" != "type" ]]; then
		    CAMEL_NAME="$CAMEL_NAME${p^}"
	    fi
	done

	echo $CAMEL_NAME
}

while getopts n:m:e:t:i:p:s: flag
do
    case "${flag}" in
        n) NAME=${OPTARG};;
        m) MODULE=${OPTARG};;
        e) EXTENDS_TYPE=${OPTARG};;
        i) INTERFACE_TYPE=${OPTARG};;
        p) PROPS+=("${OPTARG}");;
        s) SIGS+=("${OPTARG}");;
    esac
done

if [ -z "$NAME" ]; then
    echo "A name (-n) is needed, on the form name_in_lowercase"
    exit 1
fi

if [ -z "$MODULE" ]; then
    echo "A module name space (-m) is needed, on the form module_in_lowercase"
    exit 1
fi

if [ -z "$EXTENDS_TYPE" ]; then
  EXTENDS="GObject"
  EXTENDS_TYPE="G_TYPE_OBJECT"
else
  if [[ "$EXTENDS_TYPE" == *"_TYPE_"* ]]; then
    EXTENDS=$(type_to_camel "$EXTENDS_TYPE")
  else
    echo "-e EXTENDS should be a type, ie G_TYPE_OBJECT (default) was $EXTENDS_TYPE"
    exit 1
  fi
fi


FULL_NAME="${MODULE}_${NAME}"
TYPE="${MODULE^^}_TYPE_${NAME^^}"

PARTS=$(echo $FULL_NAME | tr "_" "\n")
for p in $PARTS
do
    CAMEL_NAME="$CAMEL_NAME${p^}"
done

CAST=${FULL_NAME^^}

if [ -z "$EXTENDS_TYPE" ]; then
  PREFIX=$(echo "$EXTENDS" | cut -f 1 -d _)
  echo $PREFIX
fi

IFACE_INIT=""
if [ -z "$INTERFACE_TYPE" ]; then
  DEFINE_TYPE="G_DEFINE_TYPE(${CAMEL_NAME}, ${FULL_NAME}, ${EXTENDS_TYPE})"
else
  if [[ "$INTERFACE_TYPE" == *"_TYPE"* ]]; then
    IFACE_CAMEL=$(type_to_camel "$INTERFACE_TYPE")
  else
    echo "-i IMPLEMENTS should be a type, ie G_TYPE_LIST_MODEL"
    exit 1
  fi

  PARTS=$(echo ${INTERFACE_TYPE,,} | tr "_" "\n")
  SEEN_TYPE=""
  IFACE_FUNC=""
  for p in $PARTS; do
    if [ -n "$SEEN_TYPE" ]; then
      IFACE_FUNC="${IFACE_FUNC}${p}_"
    fi

    if [[ "$p"  == "type" ]]; then
	    SEEN_TYPE="y"
    fi
  done
  IFACE_FUNC="${IFACE_FUNC}interface_init"

  DEFINE_TYPE="static void $IFACE_FUNC (${IFACE_CAMEL}Interface *iface);
  G_DEFINE_TYPE_WITH_CODE (${CAMEL_NAME}, ${FULL_NAME}, ${EXTENDS_TYPE},
                         G_IMPLEMENT_INTERFACE (${INTERFACE_TYPE}, $IFACE_FUNC))"

  IFACE_INIT="static void $IFACE_FUNC (${IFACE_CAMEL}Interface *iface) { /** Add funcs to *iface */ }"
fi

for value in "${PROPS[@]}"
do
     p=${value/-/_}
     if [ -z "$PROPENUM" ]; then
        PROPENUM="typedef enum { PROP_${p^^} = 1"
        PROP_ARGLIST="const gchar *${p}"
    else
        PROP_ARGLIST="$PROP_ARGLIST, const gchar *${p}"
        PROPENUM="$PROPENUM, PROP_${p^^}"
     fi
     PUBLIC_PROPS="$PUBLIC_PROPS
     gchar *${p};"

     PROP_NEW_OBJ_ARGS="$PROP_NEW_OBJ_ARGS, \"${value}\", ${p}"

     echo $value
done


if [ -z "$PROP_ARGLIST" ]; then
  PROP_ARGLIST="void"
fi

if [ -n "$PROPENUM" ]; then
  PROPENUM="$PROPENUM, N_PROPERTIES } ${CAMEL_NAME}Property;"
  PROPLIST="static GParamSpec *obj_properties[N_PROPERTIES] = { NULL, };"

  PROP_SETTERS=""
  PROP_GETTERS=""
  PROP_DEFS=""

  for p in "${PROPS[@]}"; do
    ps=${p/-/_}
    PROP_SETTERS="$PROP_SETTERS
    case PROP_${ps^^}:
        g_free(self->${ps});
        self->${ps} = g_value_dup_string(value);
        break; "
    PROP_GETTERS="$PROP_GETTERS
    case PROP_${ps^^}:
        g_value_set_string(value, self->${ps});
        break;
        "
    PROP_DEFS="$PROP_DEFS
    obj_properties[PROP_${ps^^}] = g_param_spec_string(\"${p}\",
                                                   \"${p^}\",
                                                   \"Placeholder description.\",
                                                   NULL, /* default */
                                                   G_PARAM_READWRITE);
    "
    PROP_FREE="$PROP_FREE
    g_free(self->${ps});
    "
  done


  SET_PROPERTY="static void
set_property(GObject *object,
             guint property_id,
             const GValue *value,
             GParamSpec *pspec)
{
  ${CAMEL_NAME} *self = ${CAST}(object);

  switch ((${CAMEL_NAME}Property) property_id) {
    $PROP_SETTERS
  default:
    /* We don't have any other property... */
    G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
    break;
  }
}"

  GET_PROPERTY="static void
get_property(GObject *object,
             guint property_id,
             GValue *value,
             GParamSpec *pspec)
{
  ${CAMEL_NAME} *self = ${CAST}(object);

  switch ((${CAMEL_NAME}Property) property_id) {
    $PROP_GETTERS

  default:
    /* We don't have any other property... */
    G_OBJECT_WARN_INVALID_PROPERTY_ID(object, property_id, pspec);
    break;
  }
}"



PROP_INIT="object_class->set_property = set_property;
  object_class->get_property = get_property;

  $PROP_DEFS

  g_object_class_install_properties(object_class, N_PROPERTIES, obj_properties);
"

fi

for value in "${SIGS[@]}"
do
     p=${value/-/_}
     if [ -z "$SIGENUM" ]; then
        SIGENUM="enum ${NAME}_signals { SIG_${p^^} = 0"
    else
        SIGENUM="$SIGENUM, SIG_${p^^}"
     fi

     SIGDEFS="$SIGDEFS
     GType ${p}_types[] = { G_TYPE_STRING };
     ${NAME}_signal_defs[SIG_${p^^}] = 
          g_signal_newv(\"$value\",
                        G_TYPE_FROM_CLASS(object_class),
                        G_SIGNAL_RUN_LAST | G_SIGNAL_NO_RECURSE |
                                G_SIGNAL_NO_HOOKS,
                        NULL /* closure */,
                        NULL /* accumulator */,
                        NULL /* accumulator data */,
                        NULL /* C marshaller */,
                        G_TYPE_NONE /* return_type */,
                        G_N_ELEMENTS(${p}_types) /* n_params */,
                        ${p}_types /* param_types, or set to NULL */
          );"

          SIGNAL_DOC="$SIGNAL_DOC
/** Signal: $value
* on_$p(
*  ${CAMEL_NAME} *self,
*  const gchar *example_param,
*  gpointer user_data
*);
*
* Describe the signal here
*/"
done

if [ -n "$SIGENUM" ]; then
  SIGENUM="$SIGENUM, SIG_LAST };"
  SIG_ARRAY="static guint ${NAME}_signal_defs[SIG_LAST] = { 0 };"

fi

############## Create .h file #########################

cat << EOF > $FULL_NAME.h
#pragma once

#include <glib-object.h>

G_BEGIN_DECLS


/*
 * Type declaration.
 */

#define ${TYPE} ${FULL_NAME}_get_type()
G_DECLARE_FINAL_TYPE(${CAMEL_NAME},
                     ${FULL_NAME},
                     ${MODULE^^},
                     ${NAME^^},
                     ${EXTENDS})

${SIGNAL_DOC}

/*
 * Method definitions.
 */
${CAMEL_NAME} *${FULL_NAME}_new(${PROP_ARGLIST});

G_END_DECLS
EOF


############## Create .c file #########################

cat << EOF > $FULL_NAME.c
#include <glib.h>
#include <glib-object.h>
#include "${FULL_NAME}.h"

struct _${CAMEL_NAME} {
  ${EXTENDS} parent;
  $PUBLIC_PROPS
};

${DEFINE_TYPE}

$PROPENUM
$PROPLIST

$SIGENUM
$SIG_ARRAY

static void
${FULL_NAME}_dispose(GObject *obj)
{
  ${CAMEL_NAME} *self =  ${CAST}(obj);

  g_assert(self);

  /* Do unrefs of objects and such. The object might be used after dispose,
  * and dispose might be called several times on the same object
  */

  /* Always chain up to the parent dispose function to complete object
   * destruction. */
  G_OBJECT_CLASS(${FULL_NAME}_parent_class)->dispose(obj);
}

static void
${FULL_NAME}_finalize(GObject *obj)
{
  ${CAMEL_NAME} *self =  ${CAST}(obj);

  g_assert(self);

  /* free stuff */
    $PROP_FREE

  /* Always chain up to the parent finalize function to complete object
   * destruction. */
  G_OBJECT_CLASS(${FULL_NAME}_parent_class)->finalize(obj);
}

$GET_PROPERTY
$SET_PROPERTY

static void
${FULL_NAME}_class_init(${CAMEL_NAME}Class *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS(klass);

  object_class->dispose = ${FULL_NAME}_dispose;
  object_class->finalize = ${FULL_NAME}_finalize;
  $PROP_INIT

  $SIGDEFS
}

static void
${FULL_NAME}_init(G_GNUC_UNUSED ${CAMEL_NAME} *self)
{
  /* initialize all public and private members to reasonable default values.
   * They are all automatically initialized to 0 to begin with. */
}

$IFACE_INIT

${CAMEL_NAME} *
${FULL_NAME}_new(${PROP_ARGLIST})
{
  return g_object_new(${TYPE} ${PROP_NEW_OBJ_ARGS}, NULL);
}

EOF
