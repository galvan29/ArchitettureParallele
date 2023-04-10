#include "devicio.cpp"
#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <numeric>
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
#include <cstring>

using namespace std;

int main(int argn, char *args[])  //main
{
	int k = 50;  							                                                //number of solutiont o find
	string nomeFile = "v1.txt";
	
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
				littExist[pos] = true;
				littExist[pos1] = true;
			}
			j++;
		}
	}
	//}
	
	
	
	int status[3] = {0};                                                        //array for status: 0 for add to adj; 1 for -1 and 1 to the same litteral, 2 for the check of similar solution
	
	int* sol=new int[nNegPosLit];                                  //array of current solution
	memset(sol, 0, nNegPosLit * sizeof(int)); 
	
	
	int* alternativeSol = new int[nNegPosLit];                       //alternative solution to the current solution
	memset(alternativeSol, 0, nNegPosLit * sizeof(int)); 
	
	int indexSol = 0;                                           //index of solutions in the solution's array   
	int cSol = 0;                                               //counter of solution
	list<double> prox[1];                                       //TODO
	
	int number = nLitt+1;
	int* solReg= (int*) malloc(nNegPosLit * number*sizeof(int));                            //array of next solutions to check
	memset(solReg, 0, nNegPosLit * number * sizeof(int)); 
	
	
	
	int* finalSol=new int[nNegPosLit * k];                              //solution's array   
	
	bool* alreadyVisited=new bool[nNegPosLit];                     //array to save if a node on -1 has already been checked
	memset(alreadyVisited, false, nNegPosLit * sizeof(bool)); 
	
	auto start = std::chrono::steady_clock::now();
	memset(status, 0, 3 * sizeof(int));                                                               //check modifiche
	createConstraints(adj_matrix, nNegPosLit, sizeAdj, status);           //check for same new constraints and for new edge
	
	checkDiagonal(adj_matrix, nNegPosLit, sol);                    //check if the pair of positive and negative is present. If 1 1 and -1 -1 is present, there isn't solution
	
	auto end = std::chrono::steady_clock::now();
	std::chrono::duration<double> elapseseconds = end-start;
	cout << "elapsed time: " << elapseseconds.count() << "s\n"; 
	
	bool resumeSolution = false; //forse non serve
	i = 0;
	bool esiste = false;
	bool continua = false;
	auto start2 = std::chrono::steady_clock::now();
	
	do{
		continua = false;
		do{
			memset(status, 0, 3 * sizeof(int));                                               //set status to 0
			
			if(sol[i] == 0 && sol[i+nLitt] == 0 && resumeSolution == false){                  //start, if two sibling literals both have 0 i.e. no value.
				memcpy(alternativeSol, sol, nNegPosLit*sizeof(int));                            //copy current solution
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
					saveNextSol(solReg, alternativeSol, nNegPosLit, cSol);                             //save alternative solution
					cSol++;
					resumeSolution = true;   
					esiste = false;
				}
			}
			if(!resumeSolution){
				i++;
			}
			if(resumeSolution){

				checkRow(adj_matrix, sol, nNegPosLit, status, alreadyVisited, littExist);             //insert all 1 to litteral connected to litteral with -1

        completeSol(sol, nNegPosLit, littExist); 

                                           //if a literal has 1 and its sibling 0, I do -1 and vice versa. In order to complete the solution
				if(status[0] == 0){
          resumeSolution = false;
        }                                                                                            //check status of solution completing 
				if(status[1]==1){                                                                          //check if there is some conflict
					break;
				}
			}
		}while(i < nLitt); 
		
		if(status[1] == 0){                                                                                               //if there is no conflict
			if(indexSol > 0){                                               
				checkNewSol(sol, finalSol, nNegPosLit, indexSol, status);                                         //TODO non serve perchè viene fatto prima????             //check if the found solution already exists 
			}
			if(status[2] == 0 || indexSol == 0){
				k--;
				for (int ssif = 0; ssif < nNegPosLit; ssif++)
				{   
					finalSol[indexSol * nNegPosLit + ssif] = sol[ssif];                                                       //save new solution
				}
				indexSol++;                                                                                                   //index of solution
			}
		}
		cout<<"brod"<<endl;
		memset(status, 0, 3 * sizeof(int));
		if (cSol > 0){                                                                     //Set status to 0
			i = prox[0].back();                                                                                             //I take position i from which the solution must keep going
			prox[0].pop_back();
			cSol--;
			copyNextSol(solReg, sol, nNegPosLit, cSol);                                            //retrieves the last solution that was saved from the solutions to check.
			resumeSolution = true;
			continua = true;                                                                                                //there are another solution to check
		}
    memset(alreadyVisited, 0, nNegPosLit * sizeof(bool));
		
	}while (continua && k > 0);     
	cout<<"brdadasod"<<endl;
	auto end2 = std::chrono::steady_clock::now();
	std::chrono::duration<double> elapseseconds2 = end2-start2;
	cout << "elapsed time: " << elapseseconds2.count() << "s\n"; 
	
	ofstream myfileD;
	myfileD.open("duration.txt", std::ios_base::app);                                                                                     //save duration in duration.txt
	myfileD  <<indexSol<<";"<<nLitt<<";"<<nConstr<<";"<< elapseseconds.count()<<";"<<elapseseconds2.count() <<"s\n";
	myfileD.close();                                                                                   //break the do-while when k = 0 or I have already check all possible solution
	
	ofstream myfile;
	myfile.open ("CPUsol"+nomeFile);                                                                                       //save solution in solution.txt
	for(int ind = 0; ind < nNegPosLit*indexSol; ind++){
		myfile << finalSol[ind]<<" ";
		if(ind%nNegPosLit == (nNegPosLit-1) && ind != 0 && ind != (nNegPosLit*indexSol-1))
		myfile << "\n";
	}
	myfile.close();
	
	cout<<"TERMINATO e k vale ora: "<<k<<" . "; if(k == 0) cout<<"Ci sono tutte le soluzioni che cercavi"<<endl;
	free(adj_matrix);
	free(littExist);
	free(sol);
	free(alternativeSol);
	free(finalSol);
	free(solReg);
	free(alreadyVisited);
  return 0;
}