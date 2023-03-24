#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <sstream>
#include <numeric>
#include <cuda.h>
#include <omp.h>
#include <malloc.h>
#include <list>


using namespace std;

//gestione e cattura errori GPU
#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

void funcRead(string str[], string nomeFile)
{
  string myText;
  int p = 0;
  ifstream MyReadFile(nomeFile);
  while (getline(MyReadFile, myText))
  {
    str[p] = myText;
    p++;
  }
  MyReadFile.close();
}

string firstLine(string nomeFile)
{
  ifstream infile(nomeFile);
  string sLine;
  if (infile.good())
  {
    getline(infile, sLine);
  }
  return sLine;
}

__device__ void diagonal(bool *d_adj_matrix, int nNegPosLit, int thid)
{
  int secondo = (thid % nNegPosLit);
  int primo = floorf(thid / nNegPosLit);
  d_adj_matrix[(primo * nNegPosLit) + secondo] |= d_adj_matrix[(secondo * nNegPosLit) + primo];
}

__global__ void createConstraints(bool *d_adj_matrix, int nNegPosLit, long int sizeAdj, int *d_status)
{
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;
  for (int Pass = 0; Pass < ceilf((sizeAdj / (blockDim.x * gridDim.x))) + 1; Pass++)
  {
    thid = thid2 + Pass * (gridDim.x * blockDim.x);

    if (thid < (sizeAdj))
    {
      if (d_adj_matrix[thid])
      { 
        int secondo = (thid % nNegPosLit);
        if (secondo >= (nNegPosLit / 2))
          secondo = secondo - (nNegPosLit / 2);
        else
          secondo = secondo + (nNegPosLit / 2);                               
        int primo = floorf(thid / nNegPosLit); 
        for (int i = (secondo * nNegPosLit); i < ((secondo + 1) * nNegPosLit); i++)
        { 
          int pos = (primo * nNegPosLit) + (i % nNegPosLit);
          if(d_adj_matrix[pos] != 1){
            if (d_adj_matrix[i] && ((i % nNegPosLit) + 1) != (primo + 1))
            {    
              d_adj_matrix[pos] = 1;
              int a = (pos%nNegPosLit)*nNegPosLit;
              int b = floorf(pos/nNegPosLit);
              d_adj_matrix[a + b] = 1;
              atomicAdd(&d_status[0], 1.0f); 
            } 
          }
        }
      }
    }
    __syncthreads();

    if (thid < (nNegPosLit * nNegPosLit))
    {
      diagonal(d_adj_matrix, nNegPosLit, thid);
    }
  }
  __syncthreads();
}

__global__ void checkDiagonal(bool *adj_matrix, int nNegPosLit)
{
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  int thidCheck1 = 0;
  int thidCheck2 = 0;
  if (thid == 0)
    printf("Ho controllato la diagonale per la presenza of per esempio 2 2 and -2 -2\n");
  if (thid % (nNegPosLit + 1) == 0 && thid < (nNegPosLit * nNegPosLit))
  {
    thidCheck1 = thid;
    thidCheck2 = (nNegPosLit + 1) * (nNegPosLit / 2) + thid;
    if (adj_matrix[thidCheck1] == 1 && adj_matrix[thidCheck1] == adj_matrix[thidCheck2])
    {
      printf("Nella status %d e nella status %d hanno entrambi 1\n", thidCheck1, thidCheck2);
      printf("Quindi teoricamente non ci sono soluzioni\n\n");
    }
  }
  __syncthreads();
}

//aggiunge 1 a tutti quelli che sono collegati al -1. se il -1 è già stato controllato allora non lo controlla più

__global__ void checkRow(bool *d_adj_matrix, int *d_sol, int nNegPosLit, int *d_status, bool *d_alreadyVisited, bool *d_littExist){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < nNegPosLit){
    if(d_sol[thid] == -1 && d_alreadyVisited[thid] == 0){
      for(int i = 0; i < nNegPosLit; i++){
        if(d_adj_matrix[thid*nNegPosLit+i] == 1){
          if(d_sol[i] == 0){
            d_sol[i] = 1;
            if(i >= (nNegPosLit/2)){
              if(d_sol[i-(nNegPosLit/2)] == 1){
                d_status[1] = d_status[1] || 1;
              }
            }else if(i < (nNegPosLit/2)){
              if(d_sol[i+(nNegPosLit/2)] == 1){
                d_status[1] = d_status[1] || 1;
              }
            }
            d_status[0] = d_status[0] || 1;
          }
          if(d_sol[i] == -1){
            //printf("Questa soluzione non va bene\n");
            d_status[1] = d_status[1] || 1;
          }
          // printf("Trovato\n");
        }
      }
      d_alreadyVisited[thid] = 1;
      if(thid < (nNegPosLit/2))
        d_alreadyVisited[thid+(nNegPosLit/2)] = 1;
    }
  }
  __syncthreads();
}

int tras(int number, int let)
{
  if (number < 0)
  {
    number = abs(number) + let;
  }
  return number - 1;
}

__global__ void completeSol(int *d_sol, int nNegPosLit, bool *d_littExist)
{
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  //int thid = 0;
  if (thid < (nNegPosLit / 2))
  {
    if (d_sol[thid] == 0 && d_sol[thid + (nNegPosLit / 2)] != 0 && d_littExist[thid] == 1)
    {
      if (d_sol[thid + (nNegPosLit / 2)] == 1)
        d_sol[thid] = -1;
      else if (d_sol[thid + (nNegPosLit / 2)] == -1)
        d_sol[thid] = 1;
    }
    if (d_sol[thid] != 0 && d_sol[thid + (nNegPosLit / 2)] == 0 && d_littExist[thid + (nNegPosLit / 2)] == 1)
    {
      if (d_sol[thid] == 1)
        d_sol[thid + (nNegPosLit / 2)] = -1;
      else if (d_sol[thid] == -1)
        d_sol[thid + (nNegPosLit / 2)] = 1;
    }
  }
__syncthreads();
}

__global__ void saveNextSol(int *d_solReg, int *d_sol_backup, int nNegPosLit, int cSol){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < nNegPosLit){
    //printf("HO COPIATO %d\n" , (cSol * nNegPosLit) + thid);
    d_solReg[(cSol * nNegPosLit) + thid] = d_sol_backup[thid];
  }
  __syncthreads();
}

__global__ void copyNextSol(int *d_solReg, int *d_sol, int nNegPosLit, int cSol){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < nNegPosLit){
    d_sol[thid] = d_solReg[(cSol * nNegPosLit) + thid];
    //printf("HO COPIATO\n");
  }
  __syncthreads();
}

__global__ void checkNewSol(int *d_sol, int *d_solFinali, int nNegPosLit, int indexSol, int *d_status){         //TODO VERIFICARE
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < indexSol){
    int i = 0;
    while(i < nNegPosLit && d_solFinali[thid*nNegPosLit + i] == d_sol[i]){
      i++;
    }

    if(i==nNegPosLit)
      d_status[2] = d_status[2] || 1;
  }
  __syncthreads();
}