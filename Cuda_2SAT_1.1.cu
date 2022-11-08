/*

ArrayList<Integer[]> values = new ArrayList<>(); 
values.add(new Integer[] { 2, -4 }); 
int thid = blockIdx.x * blockDim.x + threadIdx.x;
int thidI = 0;
for(int Pass=0; Pass<ceilf((len/(blockDim.x)))+1; Pass++){
thidI = thid + Pass*(gridDim.x*blockDim.x );
if(thidI<len){

if(!CHECK[thidI] && *out){
*out=false;
}
}
}
*/

#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <bits/stdc++.h>
#include <numeric> 
#include <cuda.h>
#include <omp.h>
#include <unistd.h>
using namespace std;

__global__ void prova(int *d_adjMatrix, int len, int size, int *out){
  int thid = blockIdx.x * blockDim.x + threadIdx.x;
  /* if(thid==0){
    printf("%p %p",d_adjMatrix, d_adjMatrix[0]);
  } 
  if(thid < len && thid != 0)
  {
    int i = 0;
    printf("Ciao sono %d \n", thid);
    printf("Ciao prima mia posizione %d \n", d_adjMatrix[thid*size]);
    while(d_adjMatrix[(thid*size) +i ] != 0 && i<size){
      printf("Sono %d e sto guardando in pos %d il valore %d \n", thid, i, d_adjMatrix[(thid*size) +i]);
      i++;
    }
  }
  __syncthreads();
  if(thid == 0)
    for(int i = 0; i< len*size; i++){
      printf("%d in posizione %d\n",d_adjMatrix[i], i);
    }
  */

  // 1 TRUE  ---   -1 FALSE   --- 0 neutro
  out[1] = 1;
  if(thid == 0)
  {
      printf("Valore %d \n", out[1]);
    printf("Valore %d \n", out[12]);
  }

  __syncthreads();
}



void print(list<int>& mylist, int index)
{
  cout << "The list elements stored at the index " << 
  index << ": \n";
  
  for (auto element : mylist) 
  {
    cout<<element<<" ";
  }
  cout << '\n';
}

void print(list<int>* myContainer, int n)
{
  cout << "adj elements:\n\n";
  for (int i = 1; i < n; i++) 
  {
    print(myContainer[i], i);
  }
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
  int nTotLet = (letterali*2)+1;
  list<int> adj[nTotLet];
  list<int> adj2[nTotLet];
  
  string str[vincoli+1];
  funcRead(str);
  
  //int *letter, *d_letter;
  //letter = (int*)malloc(letterali*sizeof(int));
  
  // #pragma omp parallel shared(str, adj)
  // { 
  //  #pragma omp for schedule(auto)
  for(int i=1; i<(vincoli+1); i++){
    stringstream ss(str[i]);
    string word;
    int j = 0;
    int pos = 0;
    int pos1 = 0;
    
    while (ss >> word && j<=1) {
      if(j==0)
      pos = stoi(word);
      if(j==1){
        pos1=stoi(word);
        if(pos < 0)
        pos = abs(pos)+letterali;
        adj[pos].push_back(pos1);
      }
      if(j==1){
        if(pos1 < 0)
        pos1 = abs(pos1)+letterali;
        if(pos > letterali)
        pos = -(pos - letterali);
        adj[pos1].push_back(pos);
      }
      j++;
    }
  }
  // }
  
  for(int i = 1; i < nTotLet; i++){
    adj[i].sort();
    adj[i].unique();
  }
  list <int> :: iterator it1;
  for(int i = 1; i < nTotLet; i++){
    list <int> :: iterator it2;
    int val1 = 0;
    for(it1 = adj[i].begin(); it1 != adj[i].end(); it1++){
      val1 = *it1;
      if(val1 < 0){
        val1 = abs(val1) + letterali;
      }       
      for(it2 = adj[i].begin(); it2 != adj[i].end(); it2++){
        if(*it1!=*it2){
          adj2[val1].push_back(*it2);
          //cout<<"Inserito "<<*it2<<" nella posizione "<<val1<<endl;
        }
      }
    }
  }
  
  
  int size = 0;
  for(int i = 1; i < nTotLet; i++){
    adj[i].merge(adj2[i]);
    adj[i].sort();
    adj[i].unique();
    if(adj[i].size() > size)
      size = adj[i].size();
  }
  //utilizzo adj2
  int adjMatrix[nTotLet*size] = {0};
/*
  for(int i=1; i<nTotLet; i++){
    for(int j=0; j<2; j++){
      cout<<adjMatrix[i][j]<<" ";
    }
    cout<<endl;
  }
  cout<<endl; */

  //https://docs.nvidia.com/cuda/cusparse/index.html#coo-format

  for(int i=1; i<nTotLet; i++){
    int j = 0;
    while(adj[i].size() > 0){
      adjMatrix[(i*size) + j] = adj[i].front();
      adj[i].pop_front();
      j++;
    }
  } 



  //out potrebbe essere di bool tanto è true o false
  int *d_adjMatrix;
  cudaMalloc(&d_adjMatrix, nTotLet*size*sizeof(int));
  cudaMemcpy(d_adjMatrix, adjMatrix, nTotLet*size*sizeof(int), cudaMemcpyHostToDevice);
  //sleep(1);
  int out[nTotLet];
  int *d_out;
  cudaMalloc(&d_out, nTotLet*sizeof(int));
  prova<<<2, 32>>>(d_adjMatrix, nTotLet, size, d_out);
  cudaMemcpy(&out, d_out, sizeof(int), cudaMemcpyDeviceToHost);
  
  
  
  
  //print(adj, nTotLet);
  
  
  /*int *d_matrice;
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

*/

return 0;
}




