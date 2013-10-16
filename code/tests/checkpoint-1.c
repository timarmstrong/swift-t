/*
 * Copyright 2013 University of Chicago and Argonne National Laboratory
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License
 */

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#include <mpi.h>

#include <adlb.h>
#include <adlb-xpt.h>

#define MAX_INDEX_SIZE 512

void dump_bin(const void *data, int length)
{
  for (int i = 0; i < length; i++)
  {
    fprintf(stderr, "%02x", (int)((unsigned char*)data)[i]);
  }
}

void check_retrieve(const char *msg, const void *data, int length,
                    adlb_binary_data data2)
{
  if (data2.length != length)
  {
    fprintf(stderr, "%s: Retrieved checkpoint data length doesn't match: "
              "%i v %i\n", msg, data2.length, length);
    exit(1);
  }
  
  if (memcmp(data2.data, data, length) != 0)
  {
    fprintf(stderr, "%s: Retrieved checkpoint data doesn't match\n", msg);
    fprintf(stderr, "Original: ");
    dump_bin(data, length);
    fprintf(stderr, "\n");
    fprintf(stderr, "Retrieved: ");
    dump_bin(data2.data, length);
    fprintf(stderr, "\n");
    exit(1);
  }
}

void fill_rand_data(char *data, int length)
{
  for (int i = 0; i < length; i++)
  {
    data[i] = (char)rand();
  }
}

void test1(MPI_Comm comm);

int
main()
{
  int mpi_argc = 0;
  char** mpi_argv = NULL;

  MPI_Init(&mpi_argc, &mpi_argv);

  // Create communicator for ADLB
  MPI_Comm comm;
  MPI_Comm_dup(MPI_COMM_WORLD, &comm);

  adlb_code ac;

  int types[2] = {0, 1};
  int am_server;
  MPI_Comm worker_comm;
  ac = ADLB_Init(1, 2, types, &am_server, comm, &worker_comm);
  assert(ac == ADLB_SUCCESS);

  ac = ADLB_Xpt_init("./checkpoint-1.xpt", ADLB_NO_FLUSH, MAX_INDEX_SIZE);
  assert(ac == ADLB_SUCCESS);

  if (am_server)
  {
    ADLB_Server(1);
  }
  else
  {
    test1(comm);
  }

  ADLB_Finalize();
  MPI_Finalize();
  return 0;
}


void test1(MPI_Comm comm)
{
  int repeats = 100;
  int my_rank;
  int rc = MPI_Comm_rank(comm, &my_rank);
  assert(rc == MPI_SUCCESS);
  int comm_size;
  rc = MPI_Comm_size(comm, &comm_size);
  assert(rc == MPI_SUCCESS);

  for (int repeat = 0; repeat < repeats; repeat++)
  {
    int size = 128;
    char data[size];
    fill_rand_data(data, size);
    
    // Create unique key
    int key = my_rank + repeat * comm_size;

    adlb_code ac = ADLB_Xpt_write(&key, (int)sizeof(key), data, size,
                        ADLB_PERSIST, true);
    assert(ac == ADLB_SUCCESS);


    adlb_binary_data data2;
    ac = ADLB_Xpt_lookup(&key, (int)sizeof(key), &data2);
    assert(ac == ADLB_SUCCESS);
    
    check_retrieve("Test 1", data, size, data2); 
    ADLB_Free_binary_data(&data2);
  }
}
