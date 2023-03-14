#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <bits/stdc++.h>
#include <numeric> 
#include <cuda.h>
#include <omp.h>
using namespace std;

__global__ void accumulateKernel(bool * CHECK, int len, bool * out){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  int thidI = 0;
    
  if(thid == 0)
    *out=true;

  __syncthreads();
  
  for(int Pass=0; Pass<ceilf((len/(blockDim.x)))+1; Pass++){
    thidI = thid + Pass*(gridDim.x*blockDim.x );
    if(thidI<len){
      
      if(!CHECK[thidI] && *out){
        *out=false;
      }
    }
  }
  __syncthreads();
  
}

__global__ void trasformaDecBin(int arr[], int val, int mat[], int vincoli, bool *CHECK, int letterali){

    int thid = (blockIdx.x*blockDim.x)+threadIdx.x;
    int thidI;
    
    if(thid==0){
      for(int i=0; i<letterali; i++){ 
        if(val>0){
          arr[i]=val%2;    
          val = val/2;  
        }else{
          arr[i]=0;
        }
      } 
    }

    __syncthreads();
    for(int Pass=0; Pass<ceilf((vincoli/(gridDim.x*blockDim.x)))+1; Pass++){
      thidI = thid + Pass*(gridDim.x*blockDim.x);
      
      if(thidI<vincoli){
        int a1 = mat[thidI*3+0];
        int a2 = mat[thidI*3+1];
        if(a1 < 0){
          a1 = a1*(-1);
          if(arr[letterali-a1] == 0)
            a1 = 1;
          else
            a1 = 0;
        }
        else
          a1 = arr[letterali-a1];

        if(a2 < 0){
          a2 = a2*(-1);
          if(arr[letterali-a2] == 0)
            a2 = 1;
          else
            a2 = 0;
        }
        else
          a2 = arr[letterali-a2];

        int somma = a1 + a2;
        if(somma == 0){
          CHECK[thidI] = false;
        }else {
          CHECK[thidI] = true;
        }
      } 
    }
    __syncthreads();
}

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
  double valore = 0;
  //int arr[letterali] = {0}; 
  string str[vincoli+1];
  funcRead(str);
  

  int *letter, *d_letter;
  letter = (int*)malloc(letterali*sizeof(int));

  int matrice[vincoli*3];
  #pragma omp parallel shared(str, matrice)
  { 
    //cout<<omp_get_num_threads()<<endl;
    #pragma omp for schedule(auto)
    for(int i=1; i<(vincoli+1); i++){
      //cout<<"Ciao sono il thread: "<<omp_get_thread_num()<<endl;
      stringstream ss(str[i]);
      string word;
      int j = 0;

      while (ss >> word) {
        matrice[(i-1)*3+j] = stoi(word);
        j++;
      }
    }
  }

  int *d_matrice;
  cudaMalloc(&d_matrice, (vincoli*3)*sizeof(int));
  cudaMemcpy(d_matrice, matrice, (vincoli*3)*sizeof(int), cudaMemcpyHostToDevice);
  bool *CHECK, *d_CHECK;
  CHECK = (bool*)malloc(vincoli*sizeof(bool));

  cudaMalloc(&d_letter, letterali*sizeof(int)); 
  cudaMalloc(&d_CHECK, (vincoli)*sizeof(bool));

  cudaMemcpy(d_letter, letter, letterali*sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_CHECK, CHECK, (vincoli)*sizeof(bool), cudaMemcpyHostToDevice);

  bool *d_out;
  bool out;
  cudaMalloc(&d_out, sizeof(bool));

  int k = 0;
  i = 0;
  double elevamento = pow(2, letterali);
  //cout<<elevamento<<endl; 
  while(k<5 && valore<elevamento)
  { 
    cout<<"Sto facendo il valore "<<valore<<endl;
    cout<<valore/elevamento<<"%"<<endl;
    trasformaDecBin<<<40, 1024>>>(d_letter, valore, d_matrice, vincoli, d_CHECK, letterali);
    cudaDeviceSynchronize();
    accumulateKernel<<<40, 1024>>>(d_CHECK, vincoli, d_out);
    cudaDeviceSynchronize();
    cudaMemcpy(&out, d_out, sizeof(bool), cudaMemcpyDeviceToHost);
    if(out){  
      cout<<endl;
      cout<<"Ok per il valore "<<valore<<endl;
      k++;
    }
    valore++;
  }
  cout<<endl<<"Numero sol trovate: "<<k<<endl;

  cudaFree(d_letter);
  cudaFree(d_matrice);
  cudaFree(d_out);
  free(letter);

  return 0;
}




