#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <sstream>
#include <numeric>
#include <list>
using namespace std;

void funcRead(string str[], string nomeFile)
{
	string myText;
	int p = 0;
	ifstream MyReadFile(nomeFile);
	while (getline(MyReadFile, myText))
	{
		str[p] = myText;
		p++;
	}

	MyReadFile.close();
}

string firstLine(string nomeFile)
{
	ifstream infile(nomeFile);
	string sLine;
	if (infile.good())
	{
		getline(infile, sLine);
	}

	return sLine;
}

void createConstraints(bool *adj_matrix, int nNegPosLit, long int sizeAdj)
{
	for (int cont = 0; cont < sizeAdj; cont++)
	{
		if (adj_matrix[cont])
		{
			int secondo = (cont % nNegPosLit);
			if (secondo >= (nNegPosLit / 2))
				secondo = secondo - (nNegPosLit / 2);
			else
				secondo = secondo + (nNegPosLit / 2);
			int primo = floorf(cont / nNegPosLit);
			for (int i = (secondo *nNegPosLit); i < ((secondo + 1) *nNegPosLit); i++)
			{
				int pos = (primo *nNegPosLit) + (i % nNegPosLit);
				if (adj_matrix[pos] != 1)
				{
					if (adj_matrix[i] && ((i % nNegPosLit) + 1))
					{
						adj_matrix[pos] = 1;
						int a = (pos % nNegPosLit) *nNegPosLit;
						int b = floorf(pos / nNegPosLit);
						adj_matrix[a + b] = 1;
					}
				}
			}
		}
	}
}

bool checkDiagonal(bool *adj_matrix, int nNegPosLit, int *sol)
{
	for (int cont = 0; cont < nNegPosLit; cont++)
	{
		int contCheck2 = 0;
		if (cont % (nNegPosLit + 1) == 0 && cont < (nNegPosLit *nNegPosLit))
		{
			contCheck2 = (nNegPosLit + 1) *(nNegPosLit / 2) + cont;
			if (adj_matrix[cont] == 1 && adj_matrix[cont] == adj_matrix[contCheck2])
			{
				return false;
			}

			if (adj_matrix[cont] == 1 && adj_matrix[contCheck2] == 0)
			{
				sol[cont % nNegPosLit] = 1;
			}
			else if (adj_matrix[cont] == 0 && adj_matrix[contCheck2] == 1)
			{
				sol[contCheck2 % nNegPosLit] = 1;
			}
		}
	}

	return true;
}

void checkRow(bool *adj_matrix, int *sol, int nNegPosLit, int *status, bool *alreadyVisited, bool *littExist)
{
	for (int cont = 0; cont < nNegPosLit; cont++)
	{
		if (sol[cont] == -1 && alreadyVisited[cont] == 0)
		{
			for (int i = 0; i < nNegPosLit; i++)
			{
				if (adj_matrix[cont *nNegPosLit + i] == 1)
				{
					if (sol[i] == 0)
					{
						sol[i] = 1;
						if (i >= (nNegPosLit / 2))
						{
							if (sol[i - (nNegPosLit / 2)] == 1)
							{
								status[1] = status[1] || 1;
								return;
							}
						}
						else if (i < (nNegPosLit / 2))
						{
							if (sol[i + (nNegPosLit / 2)] == 1)
							{
								status[1] = status[1] || 1;
								return;
							}
						}

						status[0] = status[0] || 1;
					}

					if (sol[i] == -1)
					{
						status[1] = status[1] || 1;
						return;
					}
				}
			}

			alreadyVisited[cont] = 1;
			if (cont < (nNegPosLit / 2))
				alreadyVisited[cont + (nNegPosLit / 2)] = 1;
		}
	}
}

int tras(int number, int
	let)
{
	if (number < 0)
	{
		number = abs(number) +
			let;
	}

	return number - 1;
}

void completeSol(int *sol, int nNegPosLit, bool *littExist)
{
	for (int cont = 0; cont < (nNegPosLit / 2); cont++)
	{
		if (sol[cont] == 0 && sol[cont + (nNegPosLit / 2)] != 0 && littExist[cont] == 1)
		{
			if (sol[cont + (nNegPosLit / 2)] == 1)
				sol[cont] = -1;
			else if (sol[cont + (nNegPosLit / 2)] == -1)
				sol[cont] = 1;
		}

		if (sol[cont] != 0 && sol[cont + (nNegPosLit / 2)] == 0 && littExist[cont + (nNegPosLit / 2)] == 1)
		{
			if (sol[cont] == 1)
				sol[cont + (nNegPosLit / 2)] = -1;
			else if (sol[cont] == -1)
				sol[cont + (nNegPosLit / 2)] = 1;
		}
	}
}

void saveNextSol(int *solReg, int *sol_backup, int nNegPosLit, int cSol)
{
	for (int cont = 0; cont < nNegPosLit; cont++)
	{
		solReg[(cSol *nNegPosLit) + cont] = sol_backup[cont];
	}
}

void copyNextSol(int *solReg, int *sol, int nNegPosLit, int cSol)
{
	for (int cont = 0; cont < nNegPosLit; cont++)
	{
		sol[cont] = solReg[(cSol *nNegPosLit) + cont];
	}
}

void checkNewSol(int *sol, int *solFinali, int nNegPosLit, int indexSol, int *status)
{
	for (int cont = 0; cont < nNegPosLit; cont++)
	{
		if (cont < indexSol)
		{
			int i = 0;
			while (i < nNegPosLit && solFinali[cont *nNegPosLit + i] == sol[i])
			{
				i++;
			}

			if (i == nNegPosLit)
			{
				status[2] = status[2] || 1;
				return;
			}
		}
	}
}