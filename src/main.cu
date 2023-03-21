#include "device.cu"
#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <numeric>
#include <cuda.h>
#include <omp.h>
#include <malloc.h>
#include <list>
#include <string>
#include <cstdio>
#include <cstdlib>
#include <istream>
#include <sstream>
#include <algorithm>
#include <chrono>
#include <map>
#include <utility>

using namespace std;

int main(int argn, char *args[])  //main
{
	
  bool arg1 = false;
  bool arg2 = false;
  int k = 1;  							                                                //number of solutiont o find
  string nomeFile = "v1.txt";

  if(argn>1){
		for(int i=0; i<argn; i++)
			if(std::string(args[i]).substr(0,3) == "-K="){
				k = std::stoi(std::string(args[i]).substr(3));
				arg1=true;
			}
			else if(std::string(args[i]).substr(0,6) == "-file="){
				nomeFile = (std::string(args[i]).substr(6));
				arg2=true;
			}
							
	}
  if(!arg1 || !arg2){
    cout<<"Gli argomenti di input sono errati"<<endl;
    cout<<"Inserisci -K=n -file='m', con n = num di sol. max e m = file.txt dei vincoli"<<endl;
    return 0;
  }
  
  string s = firstLine(nomeFile);   //read first line of constraint file
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
  bool* adj_matrix = new bool[sizeAdj];             //adj_matrix of all 0
  memset(adj_matrix, false, sizeAdj * sizeof(bool)); 
  
  string* str= new string[nConstr + 1];
   
  funcRead(str, nomeFile);
  
  gpuErrchk(cudaGetLastError());
  bool* littExist = new bool[nNegPosLit];   //array of presence in the constraints
  memset(littExist, false, nNegPosLit * sizeof(bool)); 
  
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


  bool *d_littExist;                                                          //device litteral existance
  cudaMalloc(&d_littExist, nNegPosLit * sizeof(bool));
  cudaMemcpy(d_littExist, littExist, nNegPosLit * sizeof(bool), cudaMemcpyHostToDevice);

  gpuErrchk(cudaGetLastError());
  bool *d_adj_matrix;                                                         //device adj matrix
  cudaMalloc(&d_adj_matrix, sizeAdj * sizeof(bool));
  cudaMemcpy(d_adj_matrix, adj_matrix, sizeAdj * sizeof(bool), cudaMemcpyHostToDevice);
  cudaDeviceSynchronize();

  int status[3] = {0};                                                        //array for status: 0 for add to adj; 1 for -1 and 1 to the same litteral, 2 for the check of similar solution
  int *d_status;
  cudaMalloc(&d_status, 3 * sizeof(int));

  gpuErrchk(cudaGetLastError());
  //creo nuovi archi
  int old = 0;
  do{
    old = status[0];
    status[0] = 0;                                                            //check modifiche
    cudaMemcpy(d_status, status, 3 * sizeof(int), cudaMemcpyHostToDevice);
    cudaDeviceSynchronize();
    createConstraints<<<40, 1024>>>(d_adj_matrix, nNegPosLit, sizeAdj, d_status);           //check for same new constraints and for new edge
    cudaDeviceSynchronize();
    cudaMemcpy(status, d_status, 3 * sizeof(int), cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();
    cout<<"Bro "<<status[0]<<endl;
  }while(old < status[0]);
  
  
  checkDiagonal<<<40, 1024>>>(d_adj_matrix, nNegPosLit);                    //check if the pair of positive and negative is present. If 1 1 and -1 -1 is present, there isn't solution
  cudaDeviceSynchronize();

  gpuErrchk(cudaGetLastError());

  int* sol=new int[nNegPosLit];                                  //array of current solution
  int *d_sol;
  
  memset(sol, 0, nNegPosLit * sizeof(int)); 
  gpuErrchk(cudaMalloc((void**)&d_sol, nNegPosLit * sizeof(int)));      
  gpuErrchk(cudaMemcpy(d_sol, sol, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice));     //TODO non so se serve
  cudaDeviceSynchronize();
  
  gpuErrchk(cudaGetLastError());
  int* alternativeSol=new int[nNegPosLit];                       //alternative solution to the current solution
  memset(alternativeSol, 0, nNegPosLit * sizeof(int)); 
  
  int *d_alternativeSol;
  cudaMalloc((void**)&d_alternativeSol, nNegPosLit * sizeof(int));

  gpuErrchk(cudaGetLastError());
  int indexSol = 0;                                           //index of solutions in the solution's array   
  int cSol = 0;                                               //counter of solution
  list<double> prox[1];                                       //TODO
  
  int number = nLitt+1;
  int* solReg= (int*) malloc(nNegPosLit * number*sizeof(int));                            //array of next solutions to check
  if(solReg==NULL)
	printf("ERRORE MEMORIA");
  memset(solReg, 0, nNegPosLit * number * sizeof(int)); 
  
  gpuErrchk(cudaGetLastError());
  int *d_solReg;
  cudaMalloc((void**)&d_solReg, (nNegPosLit * number) * sizeof(int));
  gpuErrchk(cudaMemcpy(d_solReg, solReg, (nNegPosLit * number) * sizeof(int), cudaMemcpyHostToDevice));
	
  
  gpuErrchk(cudaGetLastError());
  
  int* finalSol=new int[nNegPosLit * k];                              //solution's array   
  int *d_finalSol;
  cudaMalloc((void**)&d_finalSol, (nNegPosLit * k) * sizeof(int));
  cudaMemcpy(d_finalSol, finalSol, (nNegPosLit * k) * sizeof(int), cudaMemcpyHostToDevice);

  bool* alreadyVisited=new bool[nNegPosLit];                     //array to save if a node on -1 has already been checked
  memset(alreadyVisited, false, nNegPosLit * sizeof(bool)); 
  
  
  bool *d_alreadyVisited;
  cudaMalloc((void**)&d_alreadyVisited, nNegPosLit * sizeof(bool));
  cudaMemcpy(d_alreadyVisited, alreadyVisited, nNegPosLit * sizeof(bool), cudaMemcpyHostToDevice);
  
  gpuErrchk(cudaGetLastError());
  bool resumeSolution = false; //forse non serve
  i = 0;
  bool esiste = false;
  bool continua = false;

  do{
    continua = false;
    gpuErrchk(cudaMemcpy(d_sol, sol, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice));
	  cudaDeviceSynchronize();
    gpuErrchk(cudaGetLastError());
	do{
      memset(status, 0, 3 * sizeof(int));                                               //set status to 0
      cudaMemcpy(d_status, status, 3 * sizeof(int), cudaMemcpyHostToDevice);            //copy to gpu
      
      gpuErrchk(cudaGetLastError());
 	  if(sol[i] == 0 && sol[i+nLitt] == 0 && resumeSolution == false){                  //start, if two sibling literals both have 0 i.e. no value.
        memcpy(alternativeSol, sol, nNegPosLit*sizeof(int));                            //copy current solution
        
        gpuErrchk(cudaGetLastError());
		if(littExist[i]){                                                               //give -1 to solution and 1 to alternative solution
          sol[i] = -1;
          alternativeSol[i] = 1;
          esiste = true;
        }
        if(littExist[i + nLitt]){                                                       //give 1 to solution and -1 to alternative solution
          sol[i + nLitt] = 1;
          alternativeSol[i + nLitt] = -1;
          esiste = true;
        }

        if(esiste){
          prox[0].push_back(i);
          gpuErrchk(cudaMemcpy(d_alternativeSol, alternativeSol, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice));            
          
          gpuErrchk(cudaGetLastError());
		  saveNextSol<<<40, 1024>>>(d_solReg, d_alternativeSol, nNegPosLit, cSol);                             //save alternative solution
          cudaDeviceSynchronize();
          gpuErrchk(cudaGetLastError());
		  cSol++;
		  //printf("\n__%d__\n",cSol);
          gpuErrchk(cudaMemcpy(d_sol, sol, nNegPosLit * sizeof(int), cudaMemcpyHostToDevice));                                   //copy solution to gpu
          cudaDeviceSynchronize();
		  resumeSolution = true;   
          esiste = false;
        }
      }
      if(!resumeSolution){
        i++;
      }
      if(resumeSolution){
        checkRow<<<40, 1024>>>(d_adj_matrix, d_sol, nNegPosLit, d_status, d_alreadyVisited, d_littExist);             //insert all 1 to litteral connected to litteral with -1
        cudaDeviceSynchronize();
        completeSol<<<40, 1024>>>(d_sol, nNegPosLit, d_littExist);                                                    //if a literal has 1 and its sibling 0, I do -1 and vice versa. In order to complete the solution
        cudaDeviceSynchronize();
        cudaMemcpy(status, d_status, 3 * sizeof(int), cudaMemcpyDeviceToHost);
        cudaDeviceSynchronize();
        gpuErrchk(cudaMemcpy(sol, d_sol, nNegPosLit * sizeof(int), cudaMemcpyDeviceToHost));  //Da migliorare
        cudaDeviceSynchronize();
        if(status[0] == 0)                                                                                            //check status of solution completing 
          resumeSolution = false;
        if(status[1]==1){  
          cout<<"Non esistono soluzioni da questo caso in poi per questo ramo"<<endl;                                                                                                         //check if there is some conflict
          break;
        }
      }
    }while(i < nLitt); 

    if(status[1] == 0){                                                                                               //if there is no conflict
      gpuErrchk(cudaMemcpy(sol, d_sol, nNegPosLit * sizeof(int), cudaMemcpyDeviceToHost));                                       //TODO non serve perchè viene fatto prima????
	  cudaDeviceSynchronize();
      if(indexSol > 0){                                               
        checkNewSol<<<40, 1024>>>(d_sol, d_finalSol, nNegPosLit, indexSol, d_status);                                         //TODO non serve perchè viene fatto prima????
		cudaDeviceSynchronize();                        //check if the found solution already exists 
      }
	  if(status[2] == 0 || indexSol == 0){
        k--;
        for (int ssif = 0; ssif < nNegPosLit; ssif++)
        {   
            finalSol[indexSol * nNegPosLit + ssif] = sol[ssif];                                                       //save new solution
        }
		//printf("\n::%d::\n",indexSol * nNegPosLit);
        indexSol++;                                                                                                   //index of solution
        cudaMemcpy(d_finalSol, finalSol, (nNegPosLit * k) * sizeof(int), cudaMemcpyHostToDevice);
		cudaDeviceSynchronize();
	  }
    }

    memset(status, 0, 3 * sizeof(int));
    cudaMemcpy(d_status, status, 3 * sizeof(int), cudaMemcpyHostToDevice);
    if (cSol > 0){
      memset(sol, 0, nNegPosLit * sizeof(int));                                                                       //Set status to 0
      i = prox[0].back();                                                                                             //I take position i from which the solution must keep going
      prox[0].pop_back();
      cSol--;
      cudaMemcpy(solReg, d_solReg, nNegPosLit * sizeof(int) * (cSol+1), cudaMemcpyDeviceToHost);                      //copies the length of the array I need
      
	  cudaDeviceSynchronize();
      
      /*ofstream myfile;
      myfile.open ("prossime.txt");
      for(int ab = 0; ab < nNegPosLit * (cSol+1); ab++){
        if(solReg[ab] == 1 || solReg[ab] == 0){
          myfile << solReg[ab] << "  ";
        }else{
          myfile << solReg[ab] << " ";
        }
        if(ab != 0 && ab%nNegPosLit == 0)
          myfile << "\n";
      }*/
      copyNextSol<<<40, 1024>>>(d_solReg, d_sol, nNegPosLit, cSol);                                            //retrieves the last solution that was saved from the solutions to check.
      cudaDeviceSynchronize();
      cudaMemcpy(sol, d_sol, nNegPosLit * sizeof(int), cudaMemcpyDeviceToHost);
      cudaMemcpy(d_alreadyVisited, alreadyVisited, nNegPosLit * sizeof(bool), cudaMemcpyHostToDevice);
      resumeSolution = true;
      continua = true;                                                                                                //there are another solution to check
    }

  }while (continua && k > 0);                                                                                         //break the do-while when k = 0 or I have already check all possible solution

  ofstream myfile;
  myfile.open ("sol"+nomeFile);                                                                                       //save solution in solution.txt
  for(int ind = 0; ind < nNegPosLit*indexSol; ind++){
    myfile << finalSol[ind]<<" ";
    if(ind%nNegPosLit == (nNegPosLit-1) && ind != 0 && ind != (nNegPosLit*indexSol-1))
      myfile << "\n";
  }
  myfile.close();

  cout<<"TERMINATO e k vale ora: "<<k<<" . "; if(k == 0) cout<<"Ci sono tutte le soluzioni che cercavi"<<endl;
  cudaFree(d_adj_matrix);
  cudaFree(d_littExist);
  cudaFree(d_status);
  cudaFree(d_sol);
  cudaFree(d_alternativeSol);
  cudaFree(d_finalSol);
  cudaFree(d_solReg);
  cudaFree(d_alreadyVisited);
  return 0;
}