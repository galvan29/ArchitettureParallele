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
#include <bits/stdc++.h>
// Utilizza deque #include <deque>
// Hai efficienza ad aggiungere ai lati 

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
            d_posizione[0] = 1;
          }
        }
      }
      //sistema(d_matrix, d_matrix2, length, thid);   //3 0
      //sistema2(d_matrix, d_matrix2, length, thid);
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
  cout<<"Valore negativo "<<somma<<endl;
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
  cout<<"Valore positivo "<<somma<<endl;
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
  if(thid < length && d_sol[thid] == -1 && d_visitato[thid] == 0){
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
    d_visitato[thid+(length/2)] = 1;
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

int main(void)
{
  string s = firstLine();
  string arrayyy[4];
  stringstream ss(s);
  string word;
  int i = 0;
  while (ss >> word)
  {
    arrayyy[i] = word;
    i++;
  }

  int letterali = stoi(arrayyy[2]);
  int vincoli = stoi(arrayyy[3]);
  int nTotLet = (letterali * 2);
  long int nTotLetx2 = nTotLet * nTotLet;
  bool matrix[nTotLetx2] = {0};
  string str[vincoli + 1];
  funcRead(str);
  
  bool esisteNeiVincoli[nTotLet] = {0};
  // #pragma omp parallel shared(str, adj)
  // {
  //  #pragma omp for schedule(auto)
  for (int i = 1; i <= vincoli; i++)
  {
    stringstream ss(str[i]);
    string word;
    int pos = 0;
    int pos1 = 0;
    int j = 0;
    while (ss >> word && j <= 1)
    {
      if (j == 0)
      {
        pos = tras(stoi(word), letterali);
      }
      else if (j == 1)
      {
        pos1 = tras(stoi(word), letterali);
        matrix[((pos * nTotLet) + pos1)] = 1;
        matrix[((pos1 * nTotLet) + pos)] = 1;
      }
      esisteNeiVincoli[pos] = true;
      esisteNeiVincoli[pos1] = true;
      j++;
    }
  }
  bool *d_esisteNeiVincoli;
  cudaMalloc(&d_esisteNeiVincoli, nTotLet * sizeof(bool));
  cudaMemcpy(d_esisteNeiVincoli, esisteNeiVincoli, nTotLet * sizeof(bool), cudaMemcpyHostToDevice);

  /*for(int i=0; i<nTotLet; i++){
    cout<<esisteNeiVincoli[i]<<" ";
    if((i+1) == (nTotLet/2))
      cout<<endl;
  }
  cout<<endl;
  //} */

  // https://docs.nvidia.com/cuda/cusparse/index.html#coo-format

  bool *d_matrix;
 // bool *d_matrix2;
  //bool *d_matrix3;

  cudaMalloc(&d_matrix, nTotLetx2 * sizeof(bool));
  //cudaMalloc(&d_matrix2, nTotLetx2 * sizeof(bool));
  //cudaMalloc(&d_matrix3, nTotLetx2 * sizeof(bool));

  cudaMemcpy(d_matrix, matrix, nTotLetx2 * sizeof(bool), cudaMemcpyHostToDevice);
 // cudaMemcpy(d_matrix3, matrix, nTotLetx2 * sizeof(bool), cudaMemcpyHostToDevice);
 // sleep(10);
  // bool out[nTotLet];
  // bool *d_out;
  // cudaMalloc(&d_out, nTotLetx2*sizeof(bool));

  cudaDeviceSynchronize();

  int posizione[2] = {0};
  int *d_posizione;
  cudaMalloc(&d_posizione, 2 * sizeof(int));


  prova<<<40, 1024>>>(d_matrix, nTotLet, nTotLetx2, d_posizione);
  cudaDeviceSynchronize();
  prova<<<40, 1024>>>(d_matrix, nTotLet, nTotLetx2, d_posizione);
  cudaDeviceSynchronize();

      
  posizione[0] = 0;
  cudaMemcpy(d_posizione, posizione, 2 * sizeof(int), cudaMemcpyHostToDevice);
          
    

  //cudaFree(d_matrix);
  //cudaFree(d_matrix2);
  checkDiagonale<<<40, 1024>>>(d_matrix, nTotLet);

  cudaDeviceSynchronize();

  // PROVIAMO A CERCARE UNA SOLUZIONE
  int sol[nTotLet] = {0};
  int *d_sol;
  cudaMalloc(&d_sol, nTotLet * sizeof(int));
  //cudaMemcpy(d_sol, sol, nTotLet * sizeof(int), cudaMemcpyHostToDevice);
  int sol_backup[nTotLet] = {0};
  int *d_sol_backup;
  cudaMalloc(&d_sol_backup, nTotLet * sizeof(int));

  //bool daVis[nTotLet];
  //bool *d_daVis;
  //cudaMalloc(&d_daVis, nTotLet * sizeof(bool));
  // cudaMemcpy(d_daVis, daVis, nTotLet*sizeof(int), cudaMemcpyHostToDevice);
  
  
  
  int k = 70;
  int cSol = 0;
  list<double> prox[100];
  list<bool> soluzioniRegistrate[k];

  bool visitato[nTotLet] = {0};
  bool *d_visitato;

  cudaMalloc(&d_visitato, nTotLet * sizeof(bool));
  cudaMemcpy(d_visitato, visitato, nTotLet * sizeof(bool), cudaMemcpyHostToDevice);
  cudaMemcpy(d_sol, sol, nTotLet * sizeof(int), cudaMemcpyHostToDevice);
  bool riprendoSoluzione = false;
  int temp[nTotLet];

  i = 0;

  bool esiste = false;
  bool continua = false;
  do{
    continua = false;
    cudaMemcpy(d_sol, sol, nTotLet * sizeof(int), cudaMemcpyHostToDevice);
    do{
      posizione[0] = 0;
      cudaMemcpy(d_posizione, posizione, 2 * sizeof(int), cudaMemcpyHostToDevice);
      //cout<<"Soluzione prima di dargli i valori"<<endl;
      //printInt(sol, nTotLet);
      //cout<<endl;
      if(sol[i] == 0 && sol[i+letterali] == 0 && riprendoSoluzione == false){
        memcpy(sol_backup, sol, nTotLet*sizeof(int));
        if(esisteNeiVincoli[i]){
          sol[i] = -1;
          sol_backup[i] = 1;
          esiste = true;
        }
        if(esisteNeiVincoli[i + letterali]){
          sol[i + letterali] = 1;
          sol_backup[i + letterali] = -1;
          esiste = true;
        }
        if(esiste){
         //cout<<endl<<"Provo"<<endl;
         //printInt(sol, nTotLet);
         // cout<<endl;
          prox[0].push_back(trasformaDaArrayAIntNeg(sol_backup, nTotLet));
          prox[0].push_back(i);
          prox[0].push_back(trasformaDaArrayAIntPos(sol_backup, nTotLet));
         cout<<"-------------------------------------------------"<<endl;
         cout<<"Soluzione salvata che continuerò"<<endl;
          cout<<"-------------------------------------------------"<<endl;
          printInt(sol_backup, nTotLet);
          cout<<endl; 
          cudaMemcpy(d_sol, sol, nTotLet * sizeof(int), cudaMemcpyHostToDevice);
        }
      }
      if(!riprendoSoluzione){
        if(esiste){
          //cout<<"Trovato da dare un nuovo valore"<<endl;
          riprendoSoluzione = true;   
          esiste = false;       
        }
        i++;
        //cout<<"Aumentato i, vale "<<i<<endl;
      }
      if(riprendoSoluzione){
        checkRow<<<40, 1024>>>(d_matrix, d_sol, nTotLet, d_posizione, d_visitato, d_esisteNeiVincoli);
        cudaDeviceSynchronize();
        cudaMemcpy(posizione, d_posizione, 2 * sizeof(int), cudaMemcpyDeviceToHost);
        cudaMemcpy(sol, d_sol, nTotLet * sizeof(int), cudaMemcpyDeviceToHost);  //Da migliorare
       //cout<<"posizione 0 "<<posizione[0]<<endl;
       //cout<<"posizione 1 "<<posizione[1]<<endl;
        if(posizione[0] == 0)
          riprendoSoluzione = false;
      }
     // cout<<"Valore del controllo errori "<<posizione[1]<<endl;
    }while(i < letterali && posizione[1] == 0);   //trovare modo per smettere prima

    cudaMemcpy(sol, d_sol, nTotLet * sizeof(int), cudaMemcpyDeviceToHost);   
    //cout<<endl;
    //cout<<"Soluzione:"<<endl;
    //checkSolution<<<40, 1024>>>(d_sol, nTotLet, d_posizione, d_matrix);
    cudaDeviceSynchronize();
    cudaMemcpy(posizione, d_posizione, 2 * sizeof(int), cudaMemcpyDeviceToHost);
    if(posizione[1] == 1){
      for (int ssif = 0; ssif < nTotLet; ssif++)
      {
        cout << sol[ssif] << " ";
      }
      cout<<"Non la salvo"<<endl;
    }
    else if(posizione[1] == 0){
      for (int ssif = 0; ssif < nTotLet; ssif++)
      {
        cout << sol[ssif] << " ";
      }
      cout<<"Trovata una soluzione"<<endl;
      k--;

      // Questo serve? Mi sa di si
      completaSol<<<40, 1024>>>(d_sol, nTotLet, d_esisteNeiVincoli);

      cudaMemcpy(sol, d_sol, nTotLet * sizeof(int), cudaMemcpyDeviceToHost); 
      cout<<endl<<"Soluzione sistemata"<<endl;
      for (int ssif = 0; ssif < nTotLet; ssif++)
      {
        cout << sol[ssif] << " ";
      }
      cout<<endl;



    }
      //cout<<"La salvo"<<endl;
    //cout<<endl;

    posizione[1] = 0;
    cudaMemcpy(d_posizione, posizione, 2 * sizeof(int), cudaMemcpyHostToDevice);
    if (prox[0].size() > 0){
      memset(sol, 0, nTotLet * sizeof(int));
      trasformaDaIntAArrayPos(temp, nTotLet, prox[0].back());
      prox[0].pop_back();

      cout<<"Positivo"<<endl;
      printInt(temp, nTotLet);

      i = prox[0].back();
      prox[0].pop_back();

      trasformaDaIntAArrayNeg(sol, nTotLet, prox[0].back());
      prox[0].pop_back();
      cout<<"Negativo"<<endl;
      printInt(sol, nTotLet);
      trasformaDaArrayAArray(sol, nTotLet, temp);
      printInt(sol, nTotLet);      
      cudaMemcpy(d_visitato, visitato, nTotLet * sizeof(bool), cudaMemcpyHostToDevice);
      cout<<"^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"<<endl;
      cout<<"Riprendo questa soluzione"<<endl;
      cout<<"^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"<<endl;
      riprendoSoluzione = true;
      //printInt(sol, nTotLet);
      //cout<<endl;
      continua = true;
    }


  }while (continua && k > 0);
  cout<<endl;
  cout<<"TERMINATO"<<endl;
  cout<<"k vale ora: "<<k<<endl;
  if(k == 0)
    cout<<"Ci sono tutte le soluzioni che cercavi"<<endl;
 /* cout << "Soluzioni mostrate in ordine di registrazione in valore intero: " << endl;
  cout << "Dal decimale al bin rendo 1 gli 1 e i -1 0: " << endl;
  soluzioniRegistrate[0].sort();
  soluzioniRegistrate[0].unique();
  while (soluzioniRegistrate[0].size() > 0)
  {
    cout << soluzioniRegistrate[0].front() << endl;
    soluzioniRegistrate[0].pop_front();
  }
  cout << endl;*/
  cudaFree(d_matrix);
  return 0;
}
