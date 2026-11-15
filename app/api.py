from fastapi import FastAPI, Request, HTTPException
import os
import hmac
from pydantic import BaseModel
import services as services

app = FastAPI()
API_TOKEN = os.getenv("API_TOKEN")
MAX_WG_TUNNELS = int(os.getenv("MAX_WG_TUNNELS", "10"))
MAX_NGINX_CONFIGS = int(os.getenv("MAX_NGINX_CONFIGS", "10"))


def auth(request: Request):
    api_key = request.headers.get("Authorization", "")

    if not api_key:
        raise HTTPException(
            status_code = 401,
            detail = "API key is missing!"
        )
    
    if not API_TOKEN or not hmac.compare_digest(api_key, API_TOKEN):
        raise HTTPException(
            status_code = 403,
            detail = "Invalid API key!" 
        )
    return True


def returnData(status, body = {}):
    if status == True:
        return {
            "status": "ok",
            "data": body
        }
    else:
        return {
            "status": "error",
            "data": body
        }



#-------------------------------------------
#-------------------------------------------
# wireguard
#-------------------------------------------
#-------------------------------------------

class NewTunnelBody(BaseModel):
    id: str

@app.post("/wireguard/new")
def addNewTunnel(request: Request, body: NewTunnelBody):
    print("ok")
    auth(request)
    data = services.addWgTunnel(body.id)
    if data != False:
        return returnData(True, data)
    else:
        return returnData(False)
    

class removeTunnelBody(BaseModel):
    id: str

@app.post("/wireguard/remove")
def removeTunnel(request: Request, body: removeTunnelBody):
    auth(request)
    data = services.rmWgTunnel(body.id)
    if data != False:
        return returnData(True, "tunnel deleted")
    else:
        return returnData(False)


@app.post("/wireguard/all")
def listTunnel(request: Request):
    auth(request)
    data = services.listwgTunnels()
    if data != False:
        return returnData(True, data)
    else:
        return returnData(False)

#-------------------------------------------
#-------------------------------------------
# nginx
#-------------------------------------------
#-------------------------------------------

class NewNginxBody(BaseModel):
    id: str

@app.post("/nginx/new")
def addNewConfig(request: Request, body: NewNginxBody):
    auth(request)
    data = services.addNewConfig(body.id)
    if data != False:
        return returnData(True, "New nginx configuration created")
    else:
        return returnData(False)
    

class removeConfig(BaseModel):
    id: str

@app.post("/nginx/remove")
def rmConfig(request: Request, body: removeConfig):
    auth(request)
    data = services.removeConfig(body.id)
    if data != False:
        return returnData(True, "Nginx configuration deleted")
    else:
        return returnData(False)
    

@app.post("/nginx/all")
def listTunnel(request: Request):
    auth(request)
    data = services.getAllConfig()
    if data != False:
        return returnData(True, data)
    else:
        return returnData(False)