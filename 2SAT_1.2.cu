#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <bits/stdc++.h>
#include <numeric> 
#include <cuda.h>
#include <omp.h>
#pragma comment(linker, "/STACK:200000000")
#pragma comment(linker, "/HEAP:200000000")
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

__device__ void sistema(bool *d_matrix, bool *d_matrix2, int length, int thid){
  if(d_matrix2[thid]){
    d_matrix[thid]=1;
  }
}

__device__ void sistema2(bool *d_matrix, bool *d_matrix2, int length, int thid){
  d_matrix[thid]=d_matrix2[thid];
}

__device__ void diagonale(bool *d_matrix, int length, int thid){
  int secondo = (thid%length); 
  int primo = floorf(thid/length);
  d_matrix[(primo*length)+secondo] |= d_matrix[(secondo*length)+primo];
}

__global__ void prova(bool *d_matrix, int length, bool *d_matrix2, bool *d_matrix3){
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
//length numero letterali
  int thid = 0;
  int doppio = length*length;

  for(int Pass=0; Pass<ceilf((doppio/(blockDim.x*gridDim.x)))+1; Pass++){
    thid = thid2 + Pass*(gridDim.x*blockDim.x);

    if(thid < (doppio)){
      if(d_matrix[thid]){  //thid = 4
        int secondo = (thid%length);  // 4
        int primo = floorf(thid/length);  // 0
        for(int i = (secondo*length); i < ((secondo+1)*length); i++){   //da 24
          //printf("%d %d %d\n", d_matrix[i], (primo+1), i);  
          if(d_matrix[i] && ((i%length)+1) != (primo+1)){    //24 però 24%6+1 == 1 quindi non entro
            int posizione = (primo*length) + (i%length);
            d_matrix2[posizione] = 1;
          }
        }
        int terzo = 0;
        if(secondo > (length/2)){
          terzo = secondo - (length/2);
        }else{
          terzo = secondo + (length/2);
        }
        for(int i = (terzo*length); i < ((terzo+1)*length); i++){   //da 24
          //printf("%d %d %d\n", d_matrix[i], (primo+1), i);  
          if(d_matrix[i] && ((i%length)+1) != (primo+1)){    //24 però 24%6+1 == 1 quindi non entro
            int posizione = (primo*length) + (i%length);
            d_matrix2[posizione] = 1;
          }
        }
      }
      sistema(d_matrix3, d_matrix2, length, thid);
      sistema2(d_matrix, d_matrix2, length, thid);
    }
    __syncthreads();

    if(thid < (length*length)){
      diagonale(d_matrix3, length, thid);
    }
  }
  __syncthreads();
}
//LA DIAGONALE NON MI TORNA
__global__ void checkDiagonale(bool *matrix, int length){
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thidCheck1 = 0;
  int thidCheck2 = 0;
  if(thid2%(length+1) == 0 && thid2 < (length*length)){
    thidCheck1 = thid2;
    thidCheck2 = (length+1)*(length/2) + thid2;
    if(matrix[thidCheck1] == 1 && matrix[thidCheck1] == matrix[thidCheck2]){
      printf("Nella posizione %d e nella posizione %d hanno entrambi 1\n", thidCheck1, thidCheck2);
      printf("Quindi teoricamente non ci sono soluzioni\n\n");
    }
  }
  if(thid2 == 0)
   printf("Ho controllato la diagonale\n");
  __syncthreads();  
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

  int letterali = stoi(arrayyy[2]);
  int vincoli = stoi(arrayyy[3]);
  int nTotLet = (letterali*2);
  int nTotLetx2 = nTotLet*nTotLet;
  bool matrix[nTotLetx2] = {0};
  string str[vincoli+1];
  funcRead(str);
  
  // #pragma omp parallel shared(str, adj)
  // { 
  //  #pragma omp for schedule(auto)
  for(int i=1; i<=vincoli; i++){
    stringstream ss(str[i]);
    string word;
    int pos = 0;
    int pos1 = 0;
    int j = 0;
    while (ss >> word && j<=1) {
      if(j==0){
        pos = tras(stoi(word), letterali);
      }
      else if(j == 1){
        pos1 = tras(stoi(word), letterali);
        matrix[((pos*nTotLet)+pos1)] = 1;
        matrix[((pos1*nTotLet)+pos)] = 1;
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
  cudaMalloc(&d_matrix, nTotLetx2*sizeof(bool));
  cudaMalloc(&d_matrix2, nTotLetx2*sizeof(bool));
  cudaMalloc(&d_matrix3, nTotLetx2*sizeof(bool));
  cudaDeviceSynchronize();
  cudaMemcpy(d_matrix, matrix, nTotLetx2*sizeof(bool), cudaMemcpyHostToDevice);
  cudaMemcpy(d_matrix3, matrix, nTotLetx2*sizeof(bool), cudaMemcpyHostToDevice);
  cudaDeviceSynchronize();
  //bool out[nTotLet];
  //bool *d_out;
  //cudaMalloc(&d_out, nTotLetx2*sizeof(bool));
  prova<<<40, 1024>>>(d_matrix, nTotLet, d_matrix2, d_matrix3);
  cudaDeviceSynchronize();
  checkDiagonale<<<40, 1024>>>(d_matrix3, nTotLet);
  cudaDeviceSynchronize();
  cudaMemcpy(&matrix, d_matrix3, nTotLetx2*sizeof(bool), cudaMemcpyDeviceToHost);
  //cudaMemcpy(&out, d_out, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);
  
  for(int i=0; i<nTotLetx2; i++){
    cout<<matrix[i]<<" ";
    if(i%nTotLet == (nTotLet-1))
      cout<<endl;
  }
  cout<<endl;
  //}

  return 0;
}




