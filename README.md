# Ames Stereo Pipeline (ASP) and Desktop Exploration of Remote Terrain (DERT) for CTX & HiRISE
A cheat sheet with shell scripts for generating stereo topography models from Context Camera (CTX) and High Resolution Imaging Science Experiment (HiRISE) image data. You'll first need to install and compile both ASP and USGS ISIS. See the [Ames Stereo Pipeline](https://github.com/NeoGeographyToolkit/StereoPipeline) and [USGS ISIS](https://github.com/USGS-Astrogeology/ISIS3) repositories. If you're planning to use your stereo products with ArcGIS on Windows, I've found the easiest all-in-one setup is a Linux virtual machine. I use [VirtualBox](https://www.virtualbox.org/) with [Ubuntu Desktop](https://ubuntu.com/download/desktop), but any combination of VM and reasonably modern build of Linux should suffice. You may also choose to have your stereo pipeline setup on a separate Unix-based machine or partition. [DERT](https://github.com/nasa/DERT) is another Unix-based application that in my opinion has far superior functionality to ArcScene for 3D visualization.

Generally try to choose two images with similar lighting conditions. Avoid images with obvious artifacts (stripes or bad data), poor contrast, or harsh shadows. To find good images, I usually use [Mars Orbital Data Explorer](https://ode.rsl.wustl.edu/mars/indexMapSearch.aspx) for CTX or the [HiRISE Browse Map](https://www.uahirise.org/hiwish/browse). HiRISE also maintains a (non-exhaustive) [list of stereo pairs](https://www.uahirise.org/stereo/). You can also request stereo pairs or completions in [HiWish](https://www.uahirise.org/hiwish/).

## Generating a CTX stereo DEM
*The syntax of the code used below assumes all assets are located in the same directory. Other configurations can be accommodated by changing the paths to each filename.*
```
wget <img1>.IMG
wget <img2>.IMG
```
PDS directory: `https://pds-imaging.jpl.nasa.gov/data/mro/mars_reconnaissance_orbiter/ctx/mrox_****/data/***_******_****_X[I/N]_**[N/S]***[E/W].IMG`

Make sure you're downloading the raw experimental data record (EDR) IMG files, not the derived GeoTIFFs or other formats. This is necessary for processing by ISIS. 

`./preprocess.sh` will process the two IMG files into map-projected ISIS CUB files. Make sure these are the only two IMG files in your directory.
```
stereo -s stereo.map <img1>.map.cub <img2>.map.cub <output>
```
The ASP command `stereo` takes the argument `-s stereo.map` for the config file of the same name. This file uses a CTX-optimized median filter and was originally available from Mayer (2018) but has now been archived [here](https://github.com/Micascisto/SASP/blob/sasp/config/original/ctx_map_disp_filter_7_13_0.13.stereo). Users may also want to try using a config file without the median filter [here](https://github.com/Micascisto/SASP/blob/sasp/config/original/ctx_map.stereo). I've found that `stereo.default` gives adequate results for most purposes; just make sure to set `alignment-method none` when using map-projected image cubes.

The `stereo` command takes the map-projected image cubes and performs stereo correlation to generate an initial point cloud. Use `stereo_gui` if you want to process a smaller section of the image. This generates pyramid tiles that can be reused later. Click+drag to zoom, Ctrl+click+drag to select processing extent, r to run.
```
point2dem --tr 20 *PC.tif
dem_geoid *DEM.tif
```
The ASP commands `point2dem` and `dem_geoid` convert the point cloud to a digital elevation model (DEM) and correct the elevation values in the DEM to the Mars reference spheroid (R = 3,396,190 m), respectively. `point2dem` takes the argument `--tr 20` to specify the desired resolution of the final DEM of 20 m/pix. This is the default value to make the files easier to import into DERT, which requires stacked images to have relative dimensions in powers of 2; thus, the DEMs are 1/4 the resolution of the original CTX images (5 m/pix). DEMs can be generated at other resolutions according to user preference.

`dem_geoid` exports to `<output>-DEM-adj.tif`, which can be used in ArcMap.

The above process can be fully automated by running `sbatch run_asp` in a SLURM workload manager.

## Mosaicking and filling gaps with MOLA
*The syntax of the code used below assumes all assets are located in a DIFFERENT directory than those used for the individual stereo runs above. Other configurations can be accommodated by changing the paths to each filename.*

Oftentimes ASP stereo DEMs will have holes or bad data values. One workaround is to mosaic the ASP DEMs over a tile extracted from a lower-resolution dataset. Make sure to copy all of your previously processed, geoid-adjusted DEMs, as well as your background tile, into a single directory. A list of the post-alignment DEMs in top-down mosaic order (files ending in `trans_source-DEM.tif`) should be provided by the user in `mosaic_order.lis` in the same directory.

Two versions of a similar script are provided: `pc_align_global.sh` performs a simple alignment between each CTX DEM and a background MOLA tile with no further adjustments, and is ideal for integration with the full background dataset; `pc_align_local.sh` performs additional steps to horizontally shift the background tile to more closely match the CTX DEMs, and is ideal for comparing topographic information directly to corresponding CTX visible images over a limited area or for export to 3-D visualization software such as DERT. The examples below are from the global script but are also used in the local script.
```
pc_align --max-displacement 1000 --save-transformed-source-points <tile>.tif "$tifname"-DEM-adj.tif -o "$tifname"
```
The ASP command `pc_align` uses an initial transform to obtain the correct vertical offset between each CTX DEM and the background tile. The local script uses this offset to perform an additional manual alignment on the original DEM source files.
```
dem_mosaic -l mosaic_order.lis -o ctx_mosaic
dem_mosaic --priority-blending-length 20 ctx_mosaic-tile-0.tif <tile>.tif -o ctx_mosaic_global
```
The ASP command `dem_mosaic` first mosaics the background-registered DEMs together, and then the combined CTX DEM mosaic with the background tile. In the second step, the argument `--priority-blending-length 20` is used to specify that gaps in the CTX DEM mosaic should be filled with the lower-resolution tile and blended over a distance of 20 pixels, which is avoided in the first step to maintain as much of the original high-resolution data as possible.

`dem_mosaic` steps exports to either `ctx_mosaic_global-tile-0.tif` or `ctx_mosaic_local-tile-0.tif`, which can be used in ArcMap.

Either script can be fully automated by running `sbatch run_mosaic` in a SLURM workload manager and commenting out `#` the unwanted version of the script.

## Calibrating HiRISE images
```
wget -r -l1 -nd <dir1> -A “*RED*IMG”
wget -r -l1 -nd <dir2> -A “*RED*IMG”
```
PDS directory: `https://hirise.lpl.arizona.edu/PDS/EDR/[E/P]SP/ORB_****00_****99/[E/P]SP_******_****`

These wget options will download all the HiRISE red detector images for each EDR into a single directory. If you'd rather have them save as nested directories, use the `-np` option instead of `-nd`.
```
hiedr2mosaic.py <dir1>*
hiedr2mosaic.py <dir2>*
```
The `hiedr2mosaic.py` program automates a number of processing steps to combine the data from the different HiRISE detectors into a single image. The * wildcard after the directory name ensures all the files from the different detectors are included.
```
cam2map4stereo.py <dir1>_RED.mos_hijitreged.norm.cub <dir2>_RED.mos_hijitreged.norm.cub
```
This is the same function used to map-project CTX ISIS cubes, this time with the calibrated HiRISE cubes that have been stitched together from the individual detectors in the previous step. The processing steps after this are essentially identical to those for CTX; the analogous scripts `preprocess_hirise.sh` and `run_asp_hirise` are provided that use a different HiRISE config file, also from Mayer (2018), found [here](https://github.com/Micascisto/SASP/blob/sasp/config/original/stereo.hirise_map). The output DEM resolution should be chosen according to the resolution of the original HiRISE images; use `--tr 1` for 25 cm/pix or `--tr 2` for 50 cm/pix.

## Exporting images from ArcMap to DERT
Find the vis/DEM combo you want to use. Clip Raster > set output extent to DEM, check "Maintain Clipping Extent." Right-click clipped raster layer > Export Data > check "Use Renderer" (only if image is not already 8-bit) and set resolution to "Square" at ¼ of DEM resolution (should be very close to the native resolution of the vis image). Once images are in DERT directory, run layerfactory and select DEM first. Leave tile size at default (128). Create a new landscape directory. Re-run layerfactory and select gray image. Set tile size to 4x DEM (512).

## Overlay a gradient color map in DERT
Go to “configure landscape surface and layers” (icon with three stacked rectangles). You can also adjust the vertical exaggeration in this window (2-4 is usually best). Configure > select “None” on the left and “Elevation Map” on the right, click the left arrow button. Click OK. To change the color map, go to “show color bars” (icon with RGB stripes) > Color Map > check “Gradient.” Adjust the min and max elevations as necessary to achieve the desired stretch.
