/*
 * turbine.h
 *
 *  Created on: May 4, 2011
 *      Author: wozniak
 */

#ifndef TURBINE_H
#define TURBINE_H

typedef enum
{
  TURBINE_SUCCESS,
  /** Out of memory */
  TURBINE_ERROR_OOM,
  /** Attempt to set the same datum twice */
  TURBINE_ERROR_DOUBLE_WRITE,
  /** Data set not found */
  TURBINE_ERROR_NOT_FOUND,
  /** Bad string command given to the interpreter */
  TURBINE_ERROR_COMMAND,
  /** Unknown error */
  TURBINE_ERROR_UNKNOWN
} turbine_code;

typedef long turbine_transform_id;
typedef long turbine_datum_id;

typedef struct
{
  char* name;
  char* executor;
  int inputs;
  turbine_datum_id* input;
  int outputs;
  turbine_datum_id* output;
} turbine_transform;

turbine_code turbine_init();

turbine_code turbine_datum_file_create(turbine_datum_id* id,
                                       char* path);

turbine_code turbine_rule_add(turbine_transform* transform,
                              turbine_transform_id* id);

turbine_code turbine_ready(int count, turbine_transform_id* output);

turbine_code turbine_complete(turbine_transform_id* id);

turbine_code turbine_code_tostring(turbine_code code, char* output);

turbine_code turbine_data_tostring(int length, char* output);

void turbine_finalize();

#endif
