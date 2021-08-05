# Ames Stereo Pipeline (ASP) and Desktop Exploration of Remote Terrain (DERT) for CTX & HiRISE
A cheat sheet with shell scripts for generating stereo topography models from Context Camera (CTX) and High Resolution Imaging Science Experiment (HiRISE) image data. Everything below assumes you've already installed and compiled ASP and USGS ISIS, which is required to calibrate the raw images. See the [Ames Stereo Pipeline](github.com/NeoGeographyToolkit/StereoPipeline) and [USGS ISIS](https://github.com/USGS-Astrogeology/ISIS3) repositories. If you're planning to use your stereo products with ArcGIS on Windows, I've found the easiest all-in-one setup is a Linux virtual machine. I use [VirtualBox](https://www.virtualbox.org/) with [Ubuntu Desktop](https://ubuntu.com/download/desktop), but any combination of VM and reasonably modern build of Linux should suffice. [DERT](https://github.com/nasa/DERT) is another Linux-based application that in my opinion has far superior functionality to ArcScene for 3D visualization.

Generally try to choose two images with similar lighting conditions. Avoid images with obvious artifacts (stripes or bad data), poor contrast, or harsh shadows. To find good images, I usually use [Mars Orbital Data Explorer](https://ode.rsl.wustl.edu/mars/indexMapSearch.aspx) for CTX or the [HiRISE Browse Map](https://www.uahirise.org/hiwish/browse). HiRISE also maintains a (non-exhaustive) [list of stereo pairs](https://www.uahirise.org/stereo/). You can also request stereo pairs or completions in [HiWish](https://www.uahirise.org/hiwish/).

## Generating a CTX stereo DEM
*Hint: Make a separate directory for every stereo pair – ASP generates a lot of files.*
```
wget first_image.IMG
wget second_image.IMG
```
PDS directory: `https://pds-imaging.jpl.nasa.gov/data/mro/mars_reconnaissance_orbiter/ctx/mrox_****/data/***_******_****_X[I/N]_**[N/S]***[E/W].IMG`

`./preprocess.sh` will process the two IMG files into map-projected ISIS CUB files. Make sure these are the only two IMG files in your directory.
```
stereo first_image.map.cub second_image.map.cub point_cloud_name
```
Use `stereo_gui` if you want to process a smaller section of the image. Generates pyramid tiles that can be reused later. Click+drag to zoom, Ctrl+click+drag to select processing extent, r to run. The `stereo.default` provided in this repository works nicely with the preprocessed images at this step.
```
point2dem -r D_MARS --tr 20 point_cloud_name-PC.tif
```
Specify datum as D_MARS is you want to match the Mars 2000 geographic coordinate system in ArcMap. 20 m/pix resolution averages the raw point cloud over 4x4 areas, significantly reducing DEM noise. The 2^2 difference in resolution between the DEM and original images also allows you to import everything into DERT without having to resample.
```
dem_geoid point_cloud_name-DEM.tif
```
Scales DEM values to elevations above the datum. Exports to `point_cloud_name-DEM-adj.tif`, which can be imported to ArcMap.

## Mosaicking individual CTX DEMs
Compile adjusted CTX DEMs in a single directory.
```
dem_mosaic first_point_cloud_name-DEM-adj.tif … last_point_cloud_name-DEM-adj.tif -o CTX_mosaic_name
```
Each pixel of the mosaic will take the value of the first DEM in the list that covers that location. This combines the individual CTX DEMs into a single map-projected DEM.

## Filling gaps in CTX mosaics with MOLA
Add a MOLA tile to the same directory as the adjusted CTX DEMs.

`./pc_align.sh` registers each DEM with the MOLA tile and outputs `point_cloud_name-trans_source-DEM.tif` (no need to redo the datum adjustment). 
```
dem_mosaic first_point_cloud_name-trans_source-DEM.tif … last_point_cloud_name-trans_source-DEM.tif -o CTX_mosaic_name
```
Each pixel of the mosaic will take the value of the first DEM in the list that covers that location. This combines the individual CTX DEMs into a single map-projected DEM. You can also do this without the last step to make sure there are no disparities in elevations between overlapping areas (generally a good idea).
```
dem_mosaic --priority-blending-length 20 CTX_mosaic_name-tile-0.tif mola_tile_name.tif -o combined_mosaic_name
```
Use a blending length of 20 pixels for smoother transitions between higher-resolution CTX and lower-resolution MOLA pixels. MOLA pixels are automatically interpolated to the CTX DEM resolution. Exports to `combined_mosaic_name-tile-0.tif`, which can be imported to ArcMap.

## Calibrating HiRISE images
```
wget -r -l1 -np first_image_directory -A “*RED*IMG”
wget -r -l1 -np second_image_directory -A “*RED*IMG”
```
PDS directory: `https://hirise.lpl.arizona.edu/PDS/EDR/[E/P]SP/ORB_****00_****99/[E/P]SP_******_****`

These wget options will generate a nested directory that contains all the HiRISE red detector images for each EDR. *Optional: Copy image directories to root directory for easier access (and less typing).*
```
hiedr2mosaic.py first_image_directory/*
hiedr2mosaic.py second_image_directory/*
```
The `hiedr2mosaic.py` program automates a number of processing steps to combine the data from the different HiRISE detectors into a single image. The /* wildcard operator ensures all the files in the directory are included.
```
cam2map4stereo.py first_image_name.mos_hijitreged.norm.cub second_image_name.mos_hijitreged.norm.cub
```
Proceed as above for CTX, starting after the `./preprocess.sh`. For 25 cm/pix images, use --tr 1; for 50 cm/pix, use --tr 2 in point2dem.

## Exporting images from ArcMap to DERT
Find the vis/DEM combo you want to use. Clip Raster > set output extent to DEM, check "Maintain Clipping Extent." Right-click clipped raster layer > Export Data > check "Use Renderer" (only if image is not already 8-bit) and set resolution to "Square" at ¼ of DEM resolution (should be very close to the native resolution of the vis image). Once images are in DERT directory, run layerfactory and select DEM first. Leave tile size at default (128). Create a new landscape directory. Re-run layerfactory and select gray image. Set tile size to 4x DEM (512).

## Overlay a gradient color map in DERT
Go to “configure landscape surface and layers” (icon with three stacked rectangles). You can also adjust the vertical exaggeration in this window (2-4 is usually best). Configure > select “None” on the left and “Elevation Map” on the right, click the left arrow button. Click OK. To change the color map, go to “show color bars” (icon with RGB stripes) > Color Map > check “Gradient.” Adjust the min and max elevations as necessary to achieve the desired stretch.
