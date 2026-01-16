import os

from planar import PlanarApp

from app.config import setup_prod_env_vars
from app.db.entities import Invoice
from app.flows.process_invoice import invoice_agent, process_invoice

if os.environ.get("DB_SECRET_NAME"):
    setup_prod_env_vars()

app = (
    PlanarApp(title="planar_demo")
    .register_entity(Invoice)
    .register_workflow(process_invoice)
    .register_agent(invoice_agent)
)


if __name__ == "__main__":
    print("Planar app is ready!")
    exit(0)
