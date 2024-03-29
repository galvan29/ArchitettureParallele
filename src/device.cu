#include <stdio.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include <sstream>
#include <numeric>
#include <cuda.h>
#include <omp.h>
#include <malloc.h>
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

__global__ void createConstraints(bool *d_adj_matrix, int nNegPosLit, long int sizeAdj)
{
	int thid2 = blockIdx.x *blockDim.x + threadIdx.x;
	int thid = 0;
	for (int cont = 0; cont < ceilf(sizeAdj / (gridDim.x *blockDim.x)) + 1; cont++)
	{
		thid = thid2 + cont *(gridDim.x *blockDim.x);

		if (thid < sizeAdj)
		{
			if (d_adj_matrix[thid])
			{
				int secondo = (thid % nNegPosLit);
				if (secondo >= (nNegPosLit / 2))
					secondo = secondo - (nNegPosLit / 2);
				else
					secondo = secondo + (nNegPosLit / 2);
				int primo = floorf(thid / nNegPosLit);
				for (int i = (secondo *nNegPosLit); i < ((secondo + 1) *nNegPosLit); i++)
				{
					int pos = (primo *nNegPosLit) + (i % nNegPosLit);
					if (d_adj_matrix[pos] != 1)
					{
						if (d_adj_matrix[i] && ((i % nNegPosLit) + 1))
						{
							d_adj_matrix[pos] = 1;
							int a = (pos % nNegPosLit) *nNegPosLit;
							int b = floorf(pos / nNegPosLit);
							d_adj_matrix[a + b] = 1; 
						}
					}
				}
			}
		}
	}

	__syncthreads();
}

__global__ void checkDiagonal(bool *adj_matrix, int nNegPosLit, int *d_sol, int *d_status)
{
	int thid2 = blockIdx.x *blockDim.x + threadIdx.x;
	int thid = 0;
	for (int cont = 0; cont < ceilf(nNegPosLit / (blockDim.x *gridDim.x)) + 1; cont++)
	{
		thid = thid2 + cont *(gridDim.x *blockDim.x);
		int thidCheck2 = 0;
		if (thid % (nNegPosLit + 1) == 0 && thid < (nNegPosLit *nNegPosLit))
		{
			thidCheck2 = (nNegPosLit + 1) *(nNegPosLit / 2) + thid;
			if (adj_matrix[thid] == 1 && adj_matrix[thid] == adj_matrix[thidCheck2])
			{
				d_status[0] = d_status[0] || 1;
			}

			if (adj_matrix[thid] == 1 && adj_matrix[thidCheck2] == 0)
			{
				d_sol[thid % nNegPosLit] = 1;
			}
			else if (adj_matrix[thid] == 0 && adj_matrix[thidCheck2] == 1)
			{
				d_sol[thidCheck2 % nNegPosLit] = 1;
			}
		}
	}

	__syncthreads();
}

__global__ void checkRow(bool *d_adj_matrix, int *d_sol, int nNegPosLit, int *d_status, bool *d_alreadyVisited, bool *d_littExist)
{
	int thid2 = blockIdx.x *blockDim.x + threadIdx.x;
	int thid = 0;
	for (int cont = 0; cont < ceilf(nNegPosLit / (blockDim.x *gridDim.x)) + 1; cont++)
	{
		thid = thid2 + cont *(gridDim.x *blockDim.x);
		if (thid < nNegPosLit)
		{
			if (d_sol[thid] == -1 && d_alreadyVisited[thid] == 0)
			{
				for (int i = 0; i < nNegPosLit; i++)
				{
					if (d_adj_matrix[thid *nNegPosLit + i] == 1)
					{
						if (d_sol[i] == 0)
						{
							d_sol[i] = 1;
							if (i >= (nNegPosLit / 2))
							{
								if (d_sol[i - (nNegPosLit / 2)] == 1)
								{
									d_status[1] = d_status[1] || 1;
								}
							}
							else if (i < (nNegPosLit / 2))
							{
								if (d_sol[i + (nNegPosLit / 2)] == 1)
								{
									d_status[1] = d_status[1] || 1;
								}
							}

							d_status[0] = d_status[0] || 1;
						}

						if (d_sol[i] == -1)
						{
							d_status[1] = d_status[1] || 1;
						}

					}
				}

				d_alreadyVisited[thid] = 1;
				if (thid < (nNegPosLit / 2))
					d_alreadyVisited[thid + (nNegPosLit / 2)] = 1;
			}
		}
	}

	__syncthreads();
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

__global__ void completeSol(int *d_sol, int nNegPosLit, bool *d_littExist)
{
	int thid2 = blockIdx.x *blockDim.x + threadIdx.x;
	int thid = 0;
	for (int cont = 0; cont < ceilf(nNegPosLit / (blockDim.x *gridDim.x)) + 1; cont++)
	{
		thid = thid2 + cont *(gridDim.x *blockDim.x);
		if (thid < (nNegPosLit / 2))
		{
			if (d_sol[thid] == 0 && d_sol[thid + (nNegPosLit / 2)] != 0 && d_littExist[thid] == 1)
			{
				if (d_sol[thid + (nNegPosLit / 2)] == 1)
					d_sol[thid] = -1;
				else if (d_sol[thid + (nNegPosLit / 2)] == -1)
					d_sol[thid] = 1;
			}

			if (d_sol[thid] != 0 && d_sol[thid + (nNegPosLit / 2)] == 0 && d_littExist[thid + (nNegPosLit / 2)] == 1)
			{
				if (d_sol[thid] == 1)
					d_sol[thid + (nNegPosLit / 2)] = -1;
				else if (d_sol[thid] == -1)
					d_sol[thid + (nNegPosLit / 2)] = 1;
			}
		}
	}

	__syncthreads();
}

__global__ void saveNextSol(int *d_solReg, int *d_sol_backup, int nNegPosLit, int cSol)
{
	int thid2 = blockIdx.x *blockDim.x + threadIdx.x;
	int thid = 0;
	for (int cont = 0; cont < ceilf(nNegPosLit / (blockDim.x *gridDim.x)) + 1; cont++)
	{
		thid = thid2 + cont *(gridDim.x *blockDim.x);
		if (thid < nNegPosLit)
		{
			d_solReg[(cSol *nNegPosLit) + thid] = d_sol_backup[thid];
		}
	}

	__syncthreads();
}

__global__ void copyNextSol(int *d_solReg, int *d_sol, int nNegPosLit, int cSol)
{
	int thid2 = blockIdx.x *blockDim.x + threadIdx.x;
	int thid = 0;
	for (int cont = 0; cont < ceilf(nNegPosLit / (blockDim.x *gridDim.x)) + 1; cont++)
	{
		thid = thid2 + cont *(gridDim.x *blockDim.x);
		if (thid < nNegPosLit)
		{
			d_sol[thid] = d_solReg[(cSol *nNegPosLit) + thid];
		}
	}

	__syncthreads();
}

__global__ void checkNewSol(int *d_sol, int *d_solFinali, int nNegPosLit, int indexSol, int *d_status)
{
	int thid2 = blockIdx.x *blockDim.x + threadIdx.x;
	int thid = 0;
	for (int cont = 0; cont < ceilf(nNegPosLit / (blockDim.x *gridDim.x)) + 1; cont++)
	{
		thid = thid2 + cont *(gridDim.x *blockDim.x);
		if (thid < indexSol)
		{
			int i = 0;
			while (i < nNegPosLit && d_solFinali[thid *nNegPosLit + i] == d_sol[i])
			{
				i++;
			}

			if (i == nNegPosLit)
				d_status[2] = d_status[2] || 1;
		}
	}

	__syncthreads();
}