#https://github.com/rapidsai-community/notebooks-contrib/blob/main/getting_started_materials/intro_tutorials_and_guides/12_Introduction_to_Exploratory_Data_Analysis_using_cuDF.ipynb

import subprocess
import urllib.request,tarfile,pathlib

filenames=["NW_ground_stations_2018.tar.gz", "NW_ground_stations_2017.tar.gz", "NW_ground_stations_2016.tar.gz"]

for filename in filenames:
	urllib.request.urlretrieve('https://meteonet.umr-cnrm.fr/dataset/data/NW/ground_stations/'+filename, filename=filename)
	with tarfile.open(filename, "r") as tf:
    	    tf.extractall(path=".")
	pathlib.Path.unlink(filename)


import cudf
import cupy as cp
import pandas as pd
import gc

# Do a warm-up when benchmarking performance. Refer to the last section of code for the performance check. 
# If you get an out of memory error, you can comment out two of read_cvs lines below. Just make sure
# to update the gdf_frames line, too, to reflect which one dataset you're keeping.

# Empty DataFrame placeholders so you can select just one or two of the years of data. 
gdf_2016 = cudf.DataFrame()
gdf_2017 = cudf.DataFrame()
gdf_2018 = cudf.DataFrame()

# **********NOTE***********
# Comment out one or two of these if your GPU memory is full.
gdf_2016 = cudf.read_csv('./NW2016.csv')
gdf_2017 = cudf.read_csv('./NW2017.csv')
gdf_2018 = cudf.read_csv('./NW2018.csv')

gdf_frames =[gdf_2016,gdf_2017,gdf_2018]
GS_cudf = cudf.concat(gdf_frames,ignore_index=True)
GS_cudf.info()

del gdf_2016
del gdf_2017
del gdf_2018
gc.collect()

## Save the (concatenated) dataframe to csv file
GS_cudf.to_csv('./NW_data.csv',index=False,chunksize=500000)


# change the date column to datetime dtype, see the DataFrame info
GS_cudf['date'] = cudf.to_datetime(GS_cudf['date'])
GS_cudf.info()

# How many weather stations are covered in this dataset? 
# Call nunique() to count the distinct elements along a specified axis.

number_stations = GS_cudf['number_sta'].nunique()
print("The full dataset is composed of {} unique weather stations.".format(GS_cudf['number_sta'].nunique()))

## Investigate the the frequency of one specific station's data
## date column is datestime dtype, diff() function will calculate the delta time 
## TimedeltaProperties.seconds can help to get the delta seconds between each record, divide by 60 seconds to see the minutes difference.
delta_mins = GS_cudf['date'].diff().dt.seconds.max()/60
print(f"The data is recorded every {delta_mins} minutes")
