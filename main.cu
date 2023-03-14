#include "2SAT_2.2.cu"
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


int main(void)  //main
{
  string s = firstLine();   //read first line of constraint file
  string infoFirstLine[4];
  stringstream ss(s);
  string word;
  int i = 0;
  while (ss >> word)     //save information
  {
    infoFirstLine[i] = word;
    i++;
  }

  int nLitt = stoi(infoFirstLine[2]);             //number of literals
  int nConstr = stoi(infoFirstLine[3]);           //number of constraints
  int nNegPosLit = (nLitt * 2);                  //number of literals (negative and positive)
  long int sizeAdj = nNegPosLit * nNegPosLit;     //size of adj matrix
  bool adj_matrix[sizeAdj] = {0};             //adj_matrix of all 0
  string str[nConstr + 1];
  funcRead(str);
  
  bool littExist[nNegPosLit] = {false};   //array of presence in the constraints
  // #pragma omp parallel shared(str, adj)
  // {
  //  #pragma omp for schedule(auto)

  for (int i = 1; i <= nConstr; i++)              //marks the existence of a litteral inside the constriants
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
        pos = tras(stoi(word), nLitt);
      }
      else if (j == 1)
      {
        pos1 = tras(stoi(word), nLitt);
        adj_matrix[((pos * nNegPosLit) + pos1)] = 1;    //save the existence of constraints between two litterals 
        adj_matrix[((pos1 * nNegPosLit) + pos)] = 1;
      }
      littExist[pos] = true;
      littExist[pos1] = true;
      j++;
    }
  }
  //}


  bool *d_littExist;
  cudaMalloc(&d_littExist, nNegPosLit * sizeof(bool));
  cudaMemcpy(d_littExist, littExist, nNegPosLit * sizeof(bool), cudaMemcpyHostToDevice);

  bool *d_adj_matrix;
  cudaMalloc(&d_adj_matrix, sizeAdj * sizeof(bool));
  cudaMemcpy(d_adj_matrix, adj_matrix, sizeAdj * sizeof(bool), cudaMemcpyHostToDevice);

  cudaDeviceSynchronize();

  int posizione[3] = {0};
  int *d_posizione;
  cudaMalloc(&d_posizione, 3 * sizeof(int));

  //creo nuovi archi
  prova<<<40, 1024>>>(d_adj_matrix, nNegPosLit, sizeAdj, d_posizione);
  cudaDeviceSynchronize();
  cudaMemcpy(posizione, d_posizione, 3 * sizeof(int), cudaMemcpyDeviceToHost);
  cout<<"Bro "<<posizione[0]<<endl;
  posizione[0] = 0;
  cudaMemcpy(d_posizione, posizione, 3 * sizeof(int), cudaMemcpyHostToDevice);
  cudaDeviceSynchronize();
  prova<<<40, 1024>>>(d_adj_matrix, nNegPosLit, sizeAdj, d_posizione);
  cudaDeviceSynchronize();
  cudaMemcpy(posizione, d_posizione, 3 * sizeof(int), cudaMemcpyDeviceToHost);
  cout<<"Bro "<<posizione[0]<<endl;
  cudaDeviceSynchronize();
  //check modifiche
  posizione[0] = 0;
  cudaMemcpy(d_posizione, posizione, 3 * sizeof(int), cudaMemcpyHostToDevice);
          
  checkDiagonale<<<40, 1024>>>(d_adj_matrix, nNegPosLit);

  cudaDeviceSynchronize();

  int sol[nNegPosLit] = {0};
  int *d_sol;
  cudaMalloc(&d_sol, nNegPosLit * sizeof(int));
  int sol_backup[nNegPosLit] = {0};
  int *d_sol_backup;
  cudaMalloc(&d_sol_backup, nNegPosLit * sizeof(int));

  int k = 3;
  int indexSol = 0;
  int cSol = 0;
  list<double> prox[1];
  int solReg[nNegPosLit * 1000];
  int *d_solReg;
  cudaMalloc(&d_solReg, (nNegPosLit * 1000) * sizeof(int));
  cudaMemcpy(d_solReg, solReg, (nNegPosLit * 1000) * sizeof(int), cudaMemcpyHostToDevice);

  //array per soluzioni finali
  int solFinali[nNegPosLit * k];
  int *d_solFinali;
  cudaMalloc(&d_solFinali, (nNegPosLit * k) * sizeof(int));
  cudaMemcpy(d_solFinali, solFinali, (nNegPosLit * k) * sizeof(int), cudaMemcpyHostToDevice);

  bool visitato[nNegPosLit] = {0};
  bool *d_visitato;

  cudaMalloc(&d_visitato, nNegPosLit * sizeof(bool));
  cudaMemcpy(d_visitato, visitato, nNegPosLit * sizeof(bool), cudaMemcpyHostToDevice);
  cudaMemcpy(d_sol, sol, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice);
  bool riprendoSoluzione = false;

  i = 0;

  bool esiste = false;
  bool continua = false;
  do{
    continua = false;
    cudaMemcpy(d_sol, sol, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice);
    do{
      posizione[0] = 0;
      cudaMemcpy(d_posizione, posizione, 3 * sizeof(int), cudaMemcpyHostToDevice);
      if(sol[i] == 0 && sol[i+nLitt] == 0 && riprendoSoluzione == false){
        memcpy(sol_backup, sol, nNegPosLit*sizeof(int));
        if(littExist[i]){
          sol[i] = -1;
          sol_backup[i] = 1;
          esiste = true;
        }
        if(littExist[i + nLitt]){
          sol[i + nLitt] = 1;
          sol_backup[i + nLitt] = -1;
          esiste = true;
        }
        if(esiste){
          prox[0].push_back(i);
          cudaMemcpy(d_sol_backup, sol_backup, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice);
          //printInt(sol_backup, nNegPosLit);
          salvaSoluzioneProx<<<40, 1024>>>(d_solReg, d_sol_backup, nNegPosLit, cSol);
          //cout<<cSol<<endl; 
          cudaDeviceSynchronize();
          cSol++;
          cudaMemcpy(d_sol, sol, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice);
        }
      }
      if(!riprendoSoluzione){
        if(esiste){
          riprendoSoluzione = true;   
          esiste = false;       
        }
        i++;
        cout<<i<<endl;
      }
      if(riprendoSoluzione){
        checkRow<<<40, 1024>>>(d_adj_matrix, d_sol, nNegPosLit, d_posizione, d_visitato, d_littExist);
        cudaDeviceSynchronize();
        cudaMemcpy(posizione, d_posizione, 3 * sizeof(int), cudaMemcpyDeviceToHost);
        cudaMemcpy(sol, d_sol, nNegPosLit * sizeof(int), cudaMemcpyDeviceToHost);  //Da migliorare
        if(posizione[0] == 0)
          riprendoSoluzione = false;
      }
    }while(i < nLitt && posizione[1] == 0); 

    cudaDeviceSynchronize();
    cudaMemcpy(posizione, d_posizione, 3 * sizeof(int), cudaMemcpyDeviceToHost);
    if(posizione[1] == 0){
      //cout<<"Trovata una soluzione"<<endl;
      //printInt(sol, nNegPosLit);
      completaSol<<<40, 1024>>>(d_sol, nNegPosLit, d_littExist);
      cudaDeviceSynchronize();
      cudaMemcpy(sol, d_sol, nNegPosLit * sizeof(int), cudaMemcpyDeviceToHost); 
      /*cout<<"Soluzione sistemata"<<endl;
      for (int ssif = 0; ssif < nNegPosLit; ssif++)
      {   
          if(!littExist[ssif])
            cout<<-2<<" ";
          else
            cout << sol[ssif] << " ";
      }
      cout<<endl;
      cout<<endl;*/
      //SALVARE SE NUOVA
      //chiamo funzione 
      if(indexSol > 0)
        controlloNuovaSol<<<40, 1024>>>(d_sol, d_solFinali, nNegPosLit, indexSol, d_posizione);
      //cout<<"Valore indexaSol"<<endl;

      cudaMemcpy(posizione, d_posizione, 3 * sizeof(int), cudaMemcpyDeviceToHost);
      if(posizione[2] == 0 || indexSol == 0){
        k--;
        for (int ssif = 0; ssif < nNegPosLit; ssif++)
        {   
            solFinali[indexSol * nNegPosLit + ssif] = sol[ssif];
        }
        //printInt(sol, nNegPosLit);
        indexSol++;
        cudaMemcpy(d_solFinali, solFinali, (nNegPosLit * k) * sizeof(int), cudaMemcpyHostToDevice);
      }
     //cout<<"Array delle soluzioni"<<endl;
      //printInt(solFinali, nNegPosLit*(indexSol));
      posizione[2] = 0;
      cudaMemcpy(d_posizione, posizione, 3 * sizeof(int), cudaMemcpyHostToDevice);
    }

    posizione[1] = 0;
    cudaMemcpy(d_posizione, posizione, 3 * sizeof(int), cudaMemcpyHostToDevice);
    if (cSol > 0){
      memset(sol, 0, nNegPosLit * sizeof(int));
      i = prox[0].back();
      prox[0].pop_back();
      cSol--;
      copiaSoluzioneProx<<<40, 1024>>>(d_solReg, d_sol, nNegPosLit, cSol); 
      cudaDeviceSynchronize();
      cudaMemcpy(sol, d_sol, nNegPosLit * sizeof(int), cudaMemcpyDeviceToHost);
      //printInt(sol, nNegPosLit);
      cudaMemcpy(d_visitato, visitato, nNegPosLit * sizeof(bool), cudaMemcpyHostToDevice);
      riprendoSoluzione = true;
      continua = true;
    }

  }while (continua && k > 0);

  ofstream myfile;
  myfile.open ("solution.txt");
  for(int ind = 0; ind < nNegPosLit*indexSol; ind++){
    myfile << solFinali[ind]<<" ";
    if(ind%nNegPosLit == (nNegPosLit-1) && ind != 0 && ind != (nNegPosLit*indexSol-1))
      myfile << "\n";
  }

  myfile.close();
  cout<<endl;
  cout<<"TERMINATO"<<endl;
  cout<<"k vale ora: "<<k<<endl;
  if(k == 0)
    cout<<"Ci sono tutte le soluzioni che cercavi"<<endl;
  cudaFree(d_adj_matrix);
  cudaFree(d_littExist);
  cudaFree(d_posizione);
  cudaFree(d_sol);
  cudaFree(d_sol_backup);
  cudaFree(d_solFinali);
  cudaFree(d_solReg);
  cudaFree(d_visitato);
  return 0;
}