import uvicorn
import sys
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="FastAPI Template",
    description="FastAPI Template"
)
# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def read_root():
    # 3. Retorna una respuesta JSON
    return {"message": "Hello FastAPI!"}

if __name__ == "__main__":

    run_args = {
        "host": "0.0.0.0",
        "port": 8000,
    }

    is_frozen = getattr(sys, "frozen", False)
    # Production
    if is_frozen:
        run_args["app"] = app
        run_args["reload"] = False
    else:
        # Development
        run_args["app"] = "main:app"
        run_args["reload"] = True

    print(f"Starting server on port {run_args['port']}...")
    uvicorn.run(**run_args)
