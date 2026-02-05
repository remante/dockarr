<p align="center">
      <img src="dockarr_logo.jpeg" width="450" height="auto" align="middle">
</p>
<h1 align="center">Dock*arr</h1>
<p align="center"><a href="#project-description">Project Description</a> - <a href="#key-features">Key Features</a>

## Project Description

This is a combined docker-compose file that includes everything needed to host your own radarr, sonarr, prowlarr, bazarr, flaresolverr, sabnzbd, qbitorrent and tailscale with Mullvad VPN exit node.

It uses hard links or "atomic links", it is very important to follow the map structure guide to get it to work fully.

There are a few prerequisites, please read "Key Components"

## Key Components

Prerequisites:  

*   A host with Docker and Docker Compose plug-in installed, preferably on a VM.  
      
    
*   OPTIONAL (but recommended) Network share mounted to the host running Docker.  
      
    
*   Folder structure in your NAS or other storage solution:  
    

/data/torrents  
/data/torrents/incomplete  
  
/data/media/movies  
/data/media/tv  
  
/data/usenet  
/data/usenet/complete  
/data/usenet/incomplete  
  
Follow the eminent guide from TRaSH <a href="url">https://trash-guides.info/File-and-Folder-Structure/</a> to setup the atomic links within the \*arr applications after services are running.

## Key Features

This guide and Docker Compose file will have you up and running with a complete instance to be able to consume the media of choice behind a VPN with an Exit node attached to qBitorrent client as well as Usenet news reader/client.
