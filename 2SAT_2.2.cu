#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <bits/stdc++.h>
#include <numeric>
#include <cuda.h>
#include <omp.h>
#include <malloc.h>
#include <unistd.h>
#include <list>

using namespace std;

void funcRead(string str[])
{
  string myText;
  int p = 0;
  ifstream MyReadFile("vincoli.txt");
  while (getline(MyReadFile, myText))
  {
    str[p] = myText;
    p++;
  }
  MyReadFile.close();
}

string firstLine()
{
  ifstream infile("vincoli.txt");
  string sLine;
  if (infile.good())
  {
    getline(infile, sLine);
  }
  return sLine;
}

__device__ void diagonale(bool *d_matrix, int length, int thid)
{
  int secondo = (thid % length);
  int primo = floorf(thid / length);
  d_matrix[(primo * length) + secondo] |= d_matrix[(secondo * length) + primo];
}

__global__ void prova(bool *d_matrix, int length, long int lengthx2, int *d_posizione)
{
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;
  /*if(thid2 == 0){
    printf("Ma quante volte rientro\n");
  }*/

  for (int Pass = 0; Pass < ceilf((lengthx2 / (blockDim.x * gridDim.x))) + 1; Pass++)
  {
    thid = thid2 + Pass * (gridDim.x * blockDim.x);

    if (thid < (lengthx2))
    {
      if (d_matrix[thid])
      { // thid = 4
        int secondo = (thid % length);
        if (secondo >= (length / 2))
          secondo = secondo - (length / 2);
        else
          secondo = secondo + (length / 2);                                 // 4
        int primo = floorf(thid / length); // 0
        for (int i = (secondo * length); i < ((secondo + 1) * length); i++)
        { // da 24
          if (d_matrix[i] && ((i % length) + 1) != (primo + 1))
          { // 24 però 24%6+1 == 1 quindi non entro
            int posizione = (primo * length) + (i % length);
            d_matrix[posizione] = 1;
            //d_posizione[0] = 1;
            atomicAdd(&d_posizione[0], 1.0f); 
          } 
        }
      }
    }
    __syncthreads();

    if (thid < (length * length))
    {
      diagonale(d_matrix, length, thid);
    }
  }
  __syncthreads();
}

// LA DIAGONALE NON MI TORNA
__global__ void checkDiagonale(bool *matrix, int length)
{
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  int thidCheck1 = 0;
  int thidCheck2 = 0;
  if (thid % (length + 1) == 0 && thid < (length * length))
  {
    thidCheck1 = thid;
    thidCheck2 = (length + 1) * (length / 2) + thid;
    if (matrix[thidCheck1] == 1 && matrix[thidCheck1] == matrix[thidCheck2])
    {
      printf("Nella posizione %d e nella posizione %d hanno entrambi 1\n", thidCheck1, thidCheck2);
      printf("Quindi teoricamente non ci sono soluzioni\n\n");
    }
  }
  if (thid == 0)
    printf("Ho controllato la diagonale\n");
  __syncthreads();
}


bool checkBoolArray(bool *daVis, int length)
{
  int i = 0;
  while (i < length)
  {
    if (daVis[i])
      return true;
    i++;
  }
  return false;
}

double trasformaDaArrayAIntNeg(int *sol, int length)
{
  double somma = 0;
  for (int i = (length - 1); i >= 0; i--)
  {
    if (sol[i] == -1)
    {
      somma += pow(2, (length - 1) - i);
    }
  }
  //cout<<"Valore negativo "<<somma<<endl;
  return somma;
}

double trasformaDaArrayAIntPos(int *sol, int length)
{
  double somma = 0;
  for (int i = (length - 1); i >= 0; i--)
  {
    if (sol[i] == 1)
    {
      somma += pow(2, (length - 1) - i);
    }
  }
  //cout<<"Valore positivo "<<somma<<endl;
  return somma;
}

void trasformaDaArrayAArray(int *sol, int length, int *temp)
{
  for (int i = 0; i < length; i++)
  {
    if (sol[i] == 1)
      sol[i] = 1;
    if (temp[i] == 1)
      sol[i] = 1;
  }
}

void trasformaDaIntAArrayPos(int *sol, int length, int val)
{
  for (int i = (length - 1); i >= 0; i--)
  {
    if (val > 0)
    {
      sol[i] = val % 2;
      val = val / 2;
    }
  }
}

void trasformaDaIntAArrayNeg(int *sol, int length, int val)
{
  for (int i = (length - 1); i >= 0; i--)
  {
    if (val > 0)
    {
      sol[i] = val % 2;
      val = val / 2;
      sol[i] = sol[i]*(-1);
    }
  }
}



__global__ void checkRow(bool *d_matrix, int *d_sol, int length, int *d_posizione, bool *d_visitato, bool *d_esisteNeiVincoli){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  //int thid = 0;
    //printf("Sono thid %d e ho valore %d stato visitato? %d\n", thid, d_sol[thid], d_visitato[thid]);
  if(thid < length){
    if(d_sol[thid] == -1 && d_visitato[thid] == 0){
      for(int i = 0; i < length; i++){
        if(d_matrix[thid*length+i] == 1){
          if(d_sol[i] == 0){
            d_sol[i] = 1;
            if(i >= (length/2)){
              if(d_sol[i-(length/2)] == 1){
                d_posizione[1] = d_posizione[1] || 1;
              }
            }else if(i < (length/2)){
              if(d_sol[i+(length/2)] == 1){
                d_posizione[1] = d_posizione[1] || 1;
              }
            }
            d_posizione[0] = d_posizione[0] || 1;
          }
          if(d_sol[i] == -1){
            //printf("Questa soluzione non va bene\n");
            d_posizione[1] = d_posizione[1] || 1;
          }
          // printf("Trovato\n");
        }
      }
      d_visitato[thid] = 1;
      if(thid < (length/2))
        d_visitato[thid+(length/2)] = 1;
    }
  }
  __syncthreads();
}

#include <memory>
void printBool(bool *array, int length){
  
  for(int i = 0; i < length; i++){
    cout<<array[i]<<" ";
  }
  cout<<endl;
}
void printInt(int *array, int length){
  
  for(int i = 0; i < length; i++){
    cout<<array[i]<<" ";
  }
  cout<<endl;
}


#include <vector>
#include <algorithm>
bool cheK(std::vector<int> &sol){
  return std::any_of(sol.begin(), sol.end(), [](const int &i){return i == 0;});
}


int tras(int number, int let)
{
  if (number < 0)
  {
    number = abs(number) + let;
  }
  return number - 1;
}

bool checkIfSolZero(int *sol, int nTotLet)
{
  for (int i = 0; i < nTotLet; i++)
  {
    if (sol[i] == 0)
    {
      return true;
    }
  }
  return true;
}

__global__ void checkSolution(int *d_sol, int length, int * d_posizione, bool *d_matrix){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < length){
    //printf("Sono %d\n", thid);
    for(int i = thid*length; i < thid*(1+length); i++){
      if(d_matrix[i] == 1 && d_sol[thid] == -1 && d_sol[i%length] == -1){
        d_posizione[1] = d_posizione[1] || 1;
      }
    } 
  }

}

__global__ void completaSol(int *d_sol, int length, bool *d_esisteNeiVincoli)
{
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  //int thid = 0;
  if (thid < (length / 2))
  {
    if (d_sol[thid] == 0 && d_sol[thid + (length / 2)] != 0 && d_esisteNeiVincoli[thid] == 1)
    {
      if (d_sol[thid + (length / 2)] == 1)
        d_sol[thid] = -1;
      else if (d_sol[thid + (length / 2)] == -1)
        d_sol[thid] = 1;
    }
    if (d_sol[thid] != 0 && d_sol[thid + (length / 2)] == 0 && d_esisteNeiVincoli[thid + (length / 2)] == 1)
    {
      if (d_sol[thid] == 1)
        d_sol[thid + (length / 2)] = -1;
      else if (d_sol[thid] == -1)
        d_sol[thid + (length / 2)] = 1;
    }
  }
__syncthreads();
}

__global__ void salvaSoluzioneProx(int *d_solReg, int *d_sol_backup, int length, int cSol){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < length){
    //printf("HO COPIATO %d\n" , (cSol * length) + thid);
    d_solReg[(cSol * length) + thid] = d_sol_backup[thid];
  }
  __syncthreads();
}

__global__ void copiaSoluzioneProx(int *d_solReg, int *d_sol, int length, int cSol){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < length){
    d_sol[thid] = d_solReg[(cSol * length) + thid];
    //printf("HO COPIATO\n");
  }
  __syncthreads();
}

__global__ void newSolution(int *d_posizione){

}

__global__ void controlloNuovaSol(int *d_sol, int *d_solFinali, int length, int indexSol, int *d_posizione){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  if(thid < indexSol){
    int cont = 0;
    int i = 0;
    do{
      i++;
      cont++;
    }while(i < length && d_solFinali[thid*length + i] == d_sol[i]);

    if(cont==length)
      d_posizione[2] = d_posizione[2] || 1;
  }
  __syncthreads();
}