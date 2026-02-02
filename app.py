from fastapi import FastAPI, HTTPException, Body
from pydantic import BaseModel
import curl_cffi.requests
from main import get_quarter, login

app = FastAPI()

class LoginRequest(BaseModel):
    username: str
    password: str

@app.post("/login")
def login_route(login_request: LoginRequest):
    # login теперь возвращает словарь или None
    login_data = login(login_request.username, login_request.password)
    if not login_data:
        raise HTTPException(status_code=401, detail="Invalid credentials or login failed")
    # Возвращаем словарь с sessionid и pupilid
    return login_data

@app.get("/parse")
def parse(sessionid: str, pupilid: str):
    try:
        # Передаем оба параметра в get_quarter
        raw_list = get_quarter(sessionid, pupilid)

        if not raw_list:
            raise HTTPException(status_code=404, detail="No data found or session expired")

        return {"weeks": raw_list}

    except curl_cffi.requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="Target server timeout")
    except ValueError as e:
        raise HTTPException(status_code=422, detail=f"Parsing error: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")