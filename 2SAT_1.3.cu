#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <bits/stdc++.h>
#include <numeric> 
#include <cuda.h>
#include <omp.h>
#include <malloc.h>
#include "BigInt.hpp"

using namespace std;

void funcRead(string str[]){
  string myText;
  int p = 0;
  ifstream MyReadFile("vincoli.txt");
  while (getline (MyReadFile, myText)) {
    str[p] = myText;
    p++;
  }
  MyReadFile.close();
}

string firstLine(){
  ifstream infile("vincoli.txt");
  string sLine;
  if (infile.good()){
    getline(infile, sLine);
  }
  return sLine;
}

int tras(int number, int let){
  if(number < 0){
    number = abs(number)+let;
  }
  return number-1;
}

__device__ void sistema(bool *d_matrix, bool *d_matrix2, int thid){
  if(d_matrix2[thid]){
    d_matrix[thid]=1;
  }
}

__device__ void sistema2(bool *d_matrix, bool *d_matrix2, BigInt length, int thid){
  d_matrix[thid]=d_matrix2[thid];
}

__device__ void diagonale(bool *d_matrix, BigInt length, int thid){
  long int secondo = (thid%length).to_long(); 
  long int primo = floorf(thid/length.to_long());
  d_matrix[(primo*length.to_long())+secondo] |= d_matrix[(secondo*length.to_long())+primo];
}

__global__ void prova(bool *d_matrix, BigInt length, BigInt lengthx2, bool *d_matrix2, bool *d_matrix3){
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
//length numero letterali
  int thid = 0;
  
  for(int Pass=0; Pass<ceilf((lengthx2.to_long()/(blockDim.x*gridDim.x)))+1; Pass++){
    thid = thid2 + Pass*(gridDim.x*blockDim.x);

    if(thid < (lengthx2)){
      if(d_matrix[thid]){  //thid = 4
        BigInt secondo = (thid%length);  // 4
        BigInt primo = floorf(thid/length.to_long());  // 0
        for(BigInt i = (secondo*length); i < ((secondo+1)*length); i++){   //da 24
          //printf("%d %d %d\n", d_matrix[i], (primo+1), i);  
          if(d_matrix[i.to_long()] && ((i%length.to_long())+1) != (primo+1)){    //24 però 24%6+1 == 1 quindi non entro
            BigInt posizione = (primo*length) + (i%length);
            d_matrix2[posizione.to_long()] = 1;
          }
        }
        BigInt terzo = 0;
        if(secondo > (length/2)){
          terzo = secondo - (length/2);
        }else{
          terzo = secondo + (length/2);
        }
        for(BigInt i = (terzo*length); i < ((terzo+1)*length); i++){   //da 24
          //printf("%d %d %d\n", d_matrix[i], (primo+1), i);  
          if(d_matrix[i.to_long()] && ((i%length)+1) != (primo+1)){    //24 però 24%6+1 == 1 quindi non entro
            BigInt posizione = (primo*length) + (i%length);
            d_matrix2[posizione.to_long()] = 1;
          }
        }
      }
      sistema(d_matrix3, d_matrix2, thid);
      sistema2(d_matrix, d_matrix2, length, thid);
    }
    __syncthreads();

    if(thid < lengthx2){
      diagonale(d_matrix3, length, thid);
    }
  }
  __syncthreads();
}
//LA DIAGONALE NON MI TORNA
__global__ void checkDiagonale(bool *matrix, BigInt length, BigInt lengthx2){
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thidCheck1 = 0;
  int thidCheck2 = 0;
  BigInt big1 = (length+1);
  BigInt big2 = (length/2);
  big1 = big1 * big2;
  if(thid2%(length+1) == 0 && thid2 < lengthx2){
    thidCheck1 = thid2;
    thidCheck2 = big1.to_long() + thid2;
    if(matrix[thidCheck1] == 1 && matrix[thidCheck1] == matrix[thidCheck2]){
      printf("Nella posizione %d e nella posizione %d hanno entrambi 1\n", thidCheck1, thidCheck2);
      printf("Quindi teoricamente non ci sono soluzioni\n\n");
    }
  }
  if(thid2 == 0)
   printf("Ho controllato la diagonale\n");
  __syncthreads();  
}

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

int main(void)
{ 
  string s = firstLine();
  string arrayyy[4];
  stringstream ss(s);
  string word;
  int i=0;
  while (ss >> word) {
    arrayyy[i]=word;
    i++;
  }

  BigInt letterali = stoi(arrayyy[2]);
  BigInt vincoli = stoi(arrayyy[3]);
  BigInt nTotLet = (letterali*2);
  BigInt big1 = nTotLet;
  big1 = big1 * big1;
  bool matrix[big1.to_long()];
  string str[vincoli.to_long()+1];
  funcRead(str);

  // #pragma omp parallel shared(str, adj)
  // { 
  //  #pragma omp for schedule(auto)
  for(int i=1; i<=vincoli; i++){
    stringstream ss(str[i]);
    string word;
    BigInt pos = 0;
    BigInt pos1 = 0;
    BigInt j = 0;
    while (ss >> word && j<=1) {
      if(j==0){
        pos = tras(stoi(word), letterali.to_int());
      }
      else if(j == 1){
        pos1 = tras(stoi(word), letterali.to_int());
        matrix[((pos*nTotLet)+pos1).to_long()] = 1;
        matrix[((pos1*nTotLet)+pos).to_long()] = 1;
      }
      j++;
    }
  }

  /*for(int i=0; i<nTotLetx2; i++){
    cout<<matrix[i]<<" ";
    if(i%nTotLet == (nTotLet-1))
      cout<<endl;
  }
  cout<<endl;
  //}*/
  
  //https://docs.nvidia.com/cuda/cusparse/index.html#coo-format
  
  bool *d_matrix;
  bool *d_matrix2;
  bool *d_matrix3;

  gpuErrchk(cudaMalloc(&d_matrix, big1.to_long()*sizeof(bool)));
  gpuErrchk(cudaMalloc(&d_matrix2, big1.to_long()*sizeof(bool)));
  gpuErrchk(cudaMalloc(&d_matrix3, big1.to_long()*sizeof(bool)));
  cudaDeviceSynchronize();

  cudaMemcpy(d_matrix, matrix, big1.to_long()*sizeof(bool), cudaMemcpyHostToDevice);
  cudaMemcpy(d_matrix3, matrix, big1.to_long()*sizeof(bool), cudaMemcpyHostToDevice);
  cudaDeviceSynchronize();
  //bool out[nTotLet];
  //bool *d_out;
  //cudaMalloc(&d_out, nTotLetx2*sizeof(bool));
  prova<<<40, 1024>>>(d_matrix, nTotLet, big1, d_matrix2, d_matrix3);
  cudaDeviceSynchronize();
  cudaFree(d_matrix);
  cudaFree(d_matrix2);
  checkDiagonale<<<40, 1024>>>(d_matrix3, nTotLet, big1);
  cudaDeviceSynchronize();
  cudaMemcpy(&matrix, d_matrix3, big1.to_long()*sizeof(bool), cudaMemcpyDeviceToHost);
  //cudaMemcpy(&out, d_out, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);
  
  /*for(int i=0; i<nTotLetx2; i++){
    cout<<matrix[i]<<" ";
    if(i%nTotLet == (nTotLet-1))
      cout<<endl;
  }
  cout<<endl;
  //}*/

  return 0;
}




