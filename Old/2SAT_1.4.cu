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

__global__ void prova(bool *d_matrix, int length, long int lengthx2, bool *d_matrix2, bool *d_matrix3){
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for(int Pass=0; Pass<ceilf((lengthx2/(blockDim.x*gridDim.x)))+1; Pass++){
    thid = thid2 + Pass*(gridDim.x*blockDim.x);

    if(thid < (lengthx2)){
      if(d_matrix[thid]){  //thid = 4
        int secondo = (thid%length);  // 4
        int primo = floorf(thid/length);  // 0
        for(int i = (secondo*length); i < ((secondo+1)*length); i++){   //da 24 
          if(d_matrix[i] && ((i%length)+1) != (primo+1)){    //24 però 24%6+1 == 1 quindi non entro
            int posizione = (primo*length) + (i%length);
            d_matrix2[posizione] = 1;
          }
        }
        int terzo = 0;
        if(secondo >= (length/2)){
          terzo = secondo - (length/2);
        }else{
          terzo = secondo + (length/2);
        }
        for(int i = (terzo*length); i < ((terzo+1)*length); i++){   //da 24
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
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  int thidCheck1 = 0;
  int thidCheck2 = 0;
  if(thid%(length+1) == 0 && thid < (length*length)){
    thidCheck1 = thid;
    thidCheck2 = (length+1)*(length/2) + thid;
    if(matrix[thidCheck1] == 1 && matrix[thidCheck1] == matrix[thidCheck2]){
      printf("Nella posizione %d e nella posizione %d hanno entrambi 1\n", thidCheck1, thidCheck2);
      printf("Quindi teoricamente non ci sono soluzioni\n\n");
    }
  }
  if(thid == 0)
    printf("Ho controllato la diagonale\n");
  __syncthreads();  
}

__global__ void daVisitare(bool *matrix, int *d_daVis, int length, int index){ //length è nLet tutto per due
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for(int Pass=0; Pass<ceilf(((length/2)/(blockDim.x*gridDim.x)))+1; Pass++){
    thid = thid2 + Pass*(gridDim.x*blockDim.x);

    if(thid < (length/2)){
      if(matrix[thid+index*(length/2)])
        d_daVis[thid] = thid+index*(length/2);
    }
  }
  __syncthreads();
}

__global__ void sistemaArray(int *d_daVis, int *d_temp, int length){ //length è nLet tutto per due
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for(int Pass=0; Pass<ceilf(((length/2)/(blockDim.x*gridDim.x)))+1; Pass++){
    thid = thid2 + Pass*(gridDim.x*blockDim.x);

    if(thid < length){
      if(d_temp[thid] != 0)
        d_daVis[thid] = d_temp[thid];
    }
  }
  __syncthreads();
}

bool checkBoolArray(bool *daVis, int length){
  int i = 0;
  while(i < length){
    if(daVis[i])
      return true;
    i++;
  }

  int j = 0;
  int Posto = 0;
  while(Posto < length){
    if(daVis[Posto] != 0){
      daVis[j] = daVis[Posto];
      j++;
    }
    i++;
  }
  return false;
}

__global__ void completaSol(int *d_sol, int length){
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for(int Pass=0; Pass<ceilf(((length/2)/(blockDim.x*gridDim.x)))+1; Pass++){
    thid = thid2 + Pass*(gridDim.x*blockDim.x);
    if(thid < (length/2)){
      if(d_sol[thid] == 0 && d_sol[thid+(length/2)] != 0){
        if(d_sol[thid+(length/2)] == 1){
          d_sol[thid] = -1;
        }else if(d_sol[thid+(length/2)] == -1){
          d_sol[thid] = 1;
        }
      }
      if(d_sol[thid] != 0 && d_sol[thid+(length/2)] == 0){
        if(d_sol[thid] == 1){
          d_sol[thid+(length/2)] = -1;
        }else if(d_sol[thid] == -1){
          d_sol[thid+(length/2)] = 1;
        }
      }
    }
  }
  __syncthreads();
}

__global__ void workVisit(bool *matrix, int *d_sol, int *d_daVis, int index, int length, int *posizione, int *d_temp){
  int valore = d_sol[index];
  d_daVis[index] = 0;
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for(int Pass=0; Pass<ceilf((length/(blockDim.x*gridDim.x)))+1; Pass++){
    thid = thid2 + Pass*(gridDim.x*blockDim.x);
    //thid = thid + (index*length);
    if(thid < length && d_daVis[thid] != 0)
    {  
      //printf("Io sono %d\n", thid); // qua c'è qualcosa
      if(d_sol[d_daVis[thid]] == 0 && valore == -1){
        d_temp[thid] = d_daVis[thid];
        d_sol[d_daVis[thid]] = 1;
      }
      else if(d_sol[d_daVis[thid]] == 0 && valore == 1)
      {
        d_temp[thid] = d_daVis[thid];
        d_sol[d_daVis[thid]] = 0;  //capire cosa fare qua, dovrei diramare ? -1
      }
      else if(d_sol[d_daVis[thid]] == ((-1)*valore))
      {
        d_temp[thid] = d_daVis[thid];
      }
      else if(d_sol[d_daVis[thid]] == valore && valore == -1)
      {
        printf("Impossibile ottenere una soluzione grazie a %d\n", thid2);
        atomicAdd(posizione, 1); 
      }
    }
    __syncthreads();
  }

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
  long int nTotLetx2 = nTotLet * nTotLet;
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

  for(int i=0; i<nTotLetx2; i++){
    cout<<matrix[i]<<" ";
    if(i%nTotLet == (nTotLet-1))
      cout<<endl;
  }
  cout<<endl;
  //}
  
  //https://docs.nvidia.com/cuda/cusparse/index.html#coo-format
  
  bool *d_matrix;
  bool *d_matrix2;
  bool *d_matrix3;

  cudaMalloc(&d_matrix, nTotLetx2*sizeof(bool));
  cudaMalloc(&d_matrix2, nTotLetx2*sizeof(bool));
  cudaMalloc(&d_matrix3, nTotLetx2*sizeof(bool));

  cudaMemcpy(d_matrix, matrix, nTotLetx2*sizeof(bool), cudaMemcpyHostToDevice);
  cudaMemcpy(d_matrix3, matrix, nTotLetx2*sizeof(bool), cudaMemcpyHostToDevice);
  sleep(10);
  //bool out[nTotLet];
  //bool *d_out;
  //cudaMalloc(&d_out, nTotLetx2*sizeof(bool));
  prova<<<40, 1024>>>(d_matrix, nTotLet, nTotLetx2, d_matrix2, d_matrix3);
  cudaFree(d_matrix);
  cudaFree(d_matrix2);
  checkDiagonale<<<40, 1024>>>(d_matrix3, nTotLet);


  //PROVIAMO A CERCARE UNA SOLUZIONE
  int sol[nTotLet] = {0};
  int *d_sol;
  cudaMalloc(&d_sol, nTotLet*sizeof(int));
  int daVis[nTotLet] = {0};
  int *d_daVis;
  cudaMalloc(&d_daVis, nTotLet*sizeof(int));
  //cudaMemcpy(d_daVis, daVis, nTotLet*sizeof(int), cudaMemcpyHostToDevice);
  int posizione = 0;
  int *d_posizione;
  cudaMalloc(&d_posizione, sizeof(int));

  int temp[nTotLet] = {0};
  bool alreadyC = true;
  int *d_temp;
  cudaMalloc(&d_temp, nTotLet*sizeof(int));
  for(int i = 0; i< letterali; i++){
    cudaMemcpy(d_temp, temp, nTotLet*sizeof(int), cudaMemcpyHostToDevice);
    cout<<i<<endl;
    if(!alreadyC){
      cudaMemcpy(sol, d_sol, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);
      alreadyC = true;
    } 
    if(sol[i]==0 && sol[i+letterali]==0){
      sol[i] = -1;
      sol[i+letterali] = 1;
      daVisitare<<<40, 1024>>>(d_matrix3, d_daVis, nTotLet, i);
      cudaMemcpy(daVis, d_daVis, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);

      int j = 0;
      int Posto = 0;
      while(Posto < nTotLet){
        if(daVis[Posto] != 0){
          daVis[j] = daVis[Posto];
          j++;
        }
        i++;
      }
      cudaMemcpy(d_daVis, daVis, nTotLet*sizeof(int), cudaMemcpyHostToDevice);
      cudaMemcpy(d_sol, sol, nTotLet*sizeof(int), cudaMemcpyHostToDevice);

      int ind = 0;
      while(ind < nTotLet && daVis[0] != 0){
        if(daVis[ind] != 0){
          workVisit<<<40, 1024>>>(d_matrix3, d_sol, d_daVis, ind, nTotLet, d_posizione, d_temp);  //posizione da cui sono partito e valore che possiede
          sistemaArray<<<40, 1024>>>(d_daVis, d_temp, nTotLet);
          cudaMemcpy(daVis, d_daVis, nTotLet*sizeof(bool), cudaMemcpyDeviceToHost);

        }
        if(ind == nTotLet)
          ind = 0;
        ind++;
      }  

      completaSol<<<40, 1024>>>(d_sol, nTotLet);
      alreadyC = false;
    }
  }
  //cudaMemcpy(posizione, &d_posizione, sizeof(int), cudaMemcpyDeviceToHost);
  cout<<"Ci sono: "<<posizione<<" discrepanze"<<endl;

  cudaMemcpy(sol, d_sol, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);
  cudaMemcpy(&matrix, d_matrix3, nTotLetx2*sizeof(bool), cudaMemcpyDeviceToHost);




  //cudaMemcpy(&out, d_out, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);
  
  cout<<endl;
  for(int i=0; i<nTotLetx2; i++){
    cout<<matrix[i]<<" ";
    if(i%nTotLet == (nTotLet-1))
      cout<<endl;
  }
  cout<<endl;
  //}
  cout<<"Soluzione: "<<endl;
  for(int i=0; i<nTotLet; i++){
    cout<<sol[i]<<endl;
  }
  cout<<endl;

  
  cudaFree(d_temp);
  cudaFree(d_matrix3);
  cudaFree(d_daVis);
  cudaFree(d_sol);
  free(temp);
  free(matrix);
  free(daVis);
  return 0;
}




