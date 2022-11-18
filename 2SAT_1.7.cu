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

int tras(int number, int let)
{
  if (number < 0)
  {
    number = abs(number) + let;
  }
  return number - 1;
}

__device__ void sistema(bool *d_matrix, bool *d_matrix2, int length, int thid)
{
  if (d_matrix2[thid])
  {
    d_matrix[thid] = 1;
  }
}

__device__ void sistema2(bool *d_matrix, bool *d_matrix2, int length, int thid)
{
  d_matrix[thid] = d_matrix2[thid];
}

__device__ void diagonale(bool *d_matrix, int length, int thid)
{
  int secondo = (thid % length);
  int primo = floorf(thid / length);
  d_matrix[(primo * length) + secondo] |= d_matrix[(secondo * length) + primo];
}

__global__ void prova(bool *d_matrix, int length, long int lengthx2, bool *d_matrix2, bool *d_matrix3)
{
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for (int Pass = 0; Pass < ceilf((lengthx2 / (blockDim.x * gridDim.x))) + 1; Pass++)
  {
    thid = thid2 + Pass * (gridDim.x * blockDim.x);

    if (thid < (lengthx2))
    {
      if (d_matrix[thid])
      { // thid = 4
        int secondo = (thid % length);
        if (secondo >= (length / 2))
        {
          secondo = secondo - (length / 2);
        }
        else
        {
          secondo = secondo + (length / 2);
        }                                  // 4
        int primo = floorf(thid / length); // 0
        for (int i = (secondo * length); i < ((secondo + 1) * length); i++)
        { // da 24
          if (d_matrix[i] && ((i % length) + 1) != (primo + 1))
          { // 24 però 24%6+1 == 1 quindi non entro
            int posizione = (primo * length) + (i % length);
            d_matrix2[posizione] = 1;
          }
        }
      }
      sistema(d_matrix3, d_matrix2, length, thid);
      sistema2(d_matrix, d_matrix2, length, thid);
    }
    __syncthreads();

    if (thid < (length * length))
    {
      diagonale(d_matrix3, length, thid);
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

__global__ void daVisitare(bool *matrix, bool *d_daVis, int length, int index, int *d_sol)
{ // length è nLet tutto per due
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for (int Pass = 0; Pass < ceilf((length / (blockDim.x * gridDim.x))) + 1; Pass++)
  {
    thid = thid2 + Pass * (gridDim.x * blockDim.x);

    if (thid < length)
    {
      // printf("Sono %d di %d\n",thid, thid2);
      if (matrix[thid + index * length])
      {
        d_daVis[thid] = 1;
        d_sol[thid] = 1;
      }
    }
  }
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

__global__ void completaSol(int *d_sol, int length)
{
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;

  for (int Pass = 0; Pass < ceilf(((length / 2) / (blockDim.x * gridDim.x))) + 1; Pass++)
  {
    thid = thid2 + Pass * (gridDim.x * blockDim.x);
    if (thid < (length / 2))
    {
      if (d_sol[thid] == 0 && d_sol[thid + (length / 2)] != 0)
      {
        if (d_sol[thid + (length / 2)] == 1)
        {
          d_sol[thid] = -1;
        }
        else if (d_sol[thid + (length / 2)] == -1)
        {
          d_sol[thid] = 1;
        }
      }
      if (d_sol[thid] != 0 && d_sol[thid + (length / 2)] == 0)
      {
        if (d_sol[thid] == 1)
        {
          d_sol[thid + (length / 2)] = -1;
        }
        else if (d_sol[thid] == -1)
        {
          d_sol[thid + (length / 2)] = 1;
        }
      }
    }
  }
  __syncthreads();
}

__global__ void workVisit(bool *matrix, int *d_sol, bool *d_daVis, int index, int length, int *d_posizione, int *d_sol_backup)
{
  int valore = d_sol[index];
  d_daVis[index] = false;
  int thid2 = blockIdx.x * blockDim.x + threadIdx.x;
  int thid = 0;
  for (int Pass = 0; Pass < ceilf((length / (blockDim.x * gridDim.x))) + 1; Pass++)
  {
    thid = thid2 + Pass * (gridDim.x * blockDim.x);
    // thid = thid + (index*length);
    // printf("Io sono %d\n",thid);
    if (thid < length && d_daVis[thid])
    {
      // printf("VALORE VIDEO INIZIO %d \n", d_posizione[0]);
      // printf("Io sono %d\n",thid); // qua c'è qualcosa
      if (d_sol[thid] == 0 && valore == -1)
      {
        // printf("Io sono %d e il valore dentro d_sol[thid]: %d\n",thid, d_sol[thid]);
        d_daVis[thid] = true;
        d_sol[thid] = 1;
        // printf("Io sono %d e il valore dentro d_sol[thid]: %d\n",thid, d_sol[thid]);
      }
      else if (d_sol[thid] == 0 && valore == 1)
      {
        // printf("Io sono %d e il valore dentro d_sol[thid]: %d\n",thid, d_sol[thid]);
        d_daVis[thid] = true;
        d_sol[thid] = 1; // capire cosa fare qua, dovrei diramare ? -1
        // printf("Io sono %d e il valore dentro d_sol[thid]: %d\n",thid, d_sol[thid]);
      }
      else if (d_sol[thid] == (-1 * valore))
      {
        d_daVis[thid] = true;
      }
      else if (d_sol[thid] == valore && valore == -1)
      {
        // printf("Impossibile ottenere una soluzione grazie a %d\n", thid2);
        d_posizione[0] = d_posizione[0] || 1;
        // printf("Valore nella scheda video %d \n", d_posizione[0]);
      }
    }
    __syncthreads();
  }
  __syncthreads();
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
  return somma;
}

void trasformaDaArrayAArray(int *sol, int length, int *temp)
{
  for (int i = 0; i < length; i++)
  {
    if (sol[i] == 1)
      sol[i] = -1;
    if (temp[i] == 1)
      sol[i] = 1;
  }
}

void trasformaDaIntAArray(int *sol, int length, int val)
{
  for (int i = (length - 1); i >= 0; i--)
  {
    if (val > 0)
    {
      sol[i] = val % 2;
      val = val / 2;
    }
    else
    {
      sol[i] = -1;
    }
  }
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
      j++;
    }
  }

  /*for(int i=0; i<nTotLetx2; i++){
    cout<<matrix[i]<<" ";
    if(i%nTotLet == (nTotLet-1))
      cout<<endl;
  }
  cout<<endl;
  //} */

  // https://docs.nvidia.com/cuda/cusparse/index.html#coo-format

  bool *d_matrix;
  bool *d_matrix2;
  bool *d_matrix3;

  cudaMalloc(&d_matrix, nTotLetx2 * sizeof(bool));
  cudaMalloc(&d_matrix2, nTotLetx2 * sizeof(bool));
  cudaMalloc(&d_matrix3, nTotLetx2 * sizeof(bool));

  cudaMemcpy(d_matrix, matrix, nTotLetx2 * sizeof(bool), cudaMemcpyHostToDevice);
  cudaMemcpy(d_matrix3, matrix, nTotLetx2 * sizeof(bool), cudaMemcpyHostToDevice);
  sleep(10);
  // bool out[nTotLet];
  // bool *d_out;
  // cudaMalloc(&d_out, nTotLetx2*sizeof(bool));

  cudaDeviceSynchronize();

  prova<<<40, 1024>>>(d_matrix, nTotLet, nTotLetx2, d_matrix2, d_matrix3);
  cudaDeviceSynchronize();
  cudaFree(d_matrix);
  cudaFree(d_matrix2);
  checkDiagonale<<<40, 1024>>>(d_matrix3, nTotLet);

  cudaDeviceSynchronize();

  // PROVIAMO A CERCARE UNA SOLUZIONE
  int sol[nTotLet] = {0};
  int *d_sol;
  cudaMalloc(&d_sol, nTotLet * sizeof(int));
  cudaMemcpy(d_sol, sol, nTotLet * sizeof(int), cudaMemcpyHostToDevice);
  int sol_backup[nTotLet] = {0};
  int *d_sol_backup;
  cudaMalloc(&d_sol_backup, nTotLet * sizeof(int));

  bool daVis[nTotLet];
  bool *d_daVis;
  cudaMalloc(&d_daVis, nTotLet * sizeof(bool));
  // cudaMemcpy(d_daVis, daVis, nTotLet*sizeof(int), cudaMemcpyHostToDevice);
  int posizione[1] = {0};
  int *d_posizione;
  cudaMalloc(&d_posizione, 1 * sizeof(int));
  cudaMemcpy(d_posizione, posizione, 1 * sizeof(int), cudaMemcpyHostToDevice);

  list<double> prox[100];
  list<double> soluzioniRegistrate[1];
  /*sol[0] = -1;
  sol[0+letterali] = 1;

  sol_backup[0] = 1;
  sol_backup[0+letterali] = -1;


  //prox.push_back(trasformaDaArrayAInt(sol_backup, nTotLet));
  //prox.push_back(trasformaDaArrayAInt(sol, nTotLet));
  //cout<<"Questa è una soluzione da vedere "<<prox[0].back()<<endl; */
  bool riprendoSoluzione = false;
  int temp[nTotLet];

  do
  {
    if (prox[0].size() > 0)
      prox[0].pop_back();

    // lavoro
    bool alreadyC = true;
    int i = 0;
    do
    {
      if (!alreadyC)
      {
        cudaMemcpy(sol, d_sol, nTotLet * sizeof(int), cudaMemcpyDeviceToHost);
        alreadyC = true;
      }
      if (!riprendoSoluzione)
      {
        //cout<<i<<endl;
        if (sol[i] == 0 && sol[i + letterali] == 0)
        {
          sol[i] = -1;
          sol[i + letterali] = 1;

          sol_backup[i] = 1;
          sol_backup[i + letterali] = -1;
          prox[0].push_back(trasformaDaArrayAIntNeg(sol_backup, nTotLet));
          prox[0].push_back(i);
          prox[0].push_back(trasformaDaArrayAIntPos(sol_backup, nTotLet));
          riprendoSoluzione = true;
        }
        i++;
      }

      if (riprendoSoluzione)
      {
        cudaMemcpy(d_sol, sol, nTotLet * sizeof(int), cudaMemcpyHostToDevice);
        daVisitare<<<40, 1024>>>(d_matrix3, d_daVis, nTotLet, i, d_sol);
        cudaDeviceSynchronize();
        cudaMemcpy(daVis, d_daVis, nTotLet * sizeof(bool), cudaMemcpyDeviceToHost);

        completaSol<<<40, 1024>>>(d_sol, nTotLet);
        cudaDeviceSynchronize();

        int ind = 0;
        while (ind < nTotLet && checkBoolArray(daVis, nTotLet))
        {
          if (daVis[ind])
          {
            workVisit<<<40, 1024>>>(d_matrix3, d_sol, d_daVis, i, nTotLet, d_posizione, d_sol_backup);
            cudaDeviceSynchronize(); // posizione da cui sono partito e valore che possiede
            cudaMemcpy(daVis, d_daVis, nTotLet * sizeof(bool), cudaMemcpyDeviceToHost);
          }
          if (ind == nTotLet)
            ind = 0;
          ind++;
        }

        completaSol<<<40, 1024>>>(d_sol, nTotLet);
        cudaDeviceSynchronize();
        alreadyC = false;
        riprendoSoluzione = false;
      }

    } while (checkIfSolZero(sol, nTotLet) && i < nTotLet);

    // di una singola soluzione

    // appena finisce il ciclo devo andare a lavorare con un'altra soluzione che avevo.
    cudaMemcpy(sol, d_sol, nTotLet * sizeof(int), cudaMemcpyDeviceToHost);

    cout << endl
         << "Possibile soluzione :" << endl;
    for (int ssif = 0; ssif < nTotLet; ssif++)
    {
      cout << sol[ssif] << " ";
    }
    cout << endl;
    cudaMemcpy(posizione, d_posizione, 1 * sizeof(int), cudaMemcpyDeviceToHost);
    cout << "Valore delle discrepanze " << posizione[0] << endl;
    if (posizione[0] == 0)
    {
      soluzioniRegistrate[0].push_back(trasformaDaArrayAIntPos(sol, nTotLet));
    }
    posizione[0] = 0;
    cudaMemcpy(d_posizione, posizione, 1 * sizeof(int), cudaMemcpyHostToDevice);
    // cudaMemset(d_posizione, 0, 1*sizeof(int));
    cout << endl;
    if (prox[0].size() > 0)
    {
      trasformaDaIntAArray(temp, nTotLet, prox[0].back());
      prox[0].pop_back();
      i = prox[0].back();
      prox[0].pop_back();
      trasformaDaIntAArray(sol, nTotLet, prox[0].back());
      trasformaDaArrayAArray(sol, nTotLet, temp);
    }
    cout<<"Sto riprendendo una soluzione, con i="<<i<<" questa:"<<endl;
    for(int bella = 0; bella < nTotLet; bella++){
      cout<<sol[bella]<< " ";
    }
    cout<<endl;
    riprendoSoluzione = true;
  } while (prox[0].size() > 0);

  // cudaMemcpy(sol, d_sol, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);
  cudaMemcpy(&matrix, d_matrix3, nTotLetx2 * sizeof(bool), cudaMemcpyDeviceToHost);

  // cudaMemcpy(&out, d_out, nTotLet*sizeof(int), cudaMemcpyDeviceToHost);

  /*cout<<endl;
  for(int i=0; i<nTotLetx2; i++){
    cout<<matrix[i]<<" ";
    if(i%nTotLet == (nTotLet-1))
      cout<<endl;
  }
  cout<<endl;
  */

  cout << endl;
  cout << "Soluzioni mostrate in ordine di registrazione in valore intero: " << endl;
  cout << "Dal decimale al bin rendo 1 gli 1 e i -1 0: " << endl;
  soluzioniRegistrate[0].sort();
  soluzioniRegistrate[0].unique();
  while (soluzioniRegistrate[0].size() > 0)
  {
    cout << soluzioniRegistrate[0].front() << endl;
    soluzioniRegistrate[0].pop_front();
  }
  cout << endl;
  // double soluzNumerica = trasformaDaArrayAInt(sol, nTotLet);
  // cout<<soluzNumerica<<endl;

  cudaFree(d_matrix3);
  return 0;
}
