import os
from mistralai import Mistral
from core.config import get_settings

settings = get_settings()

client = Mistral(api_key=settings.MISTRAL_OCR_KEY)

ocr_response = client.ocr.process(
    model="mistral-ocr-latest",
    document={
        "type": "document_url",
        "document_url": "https://docs.scenic-lang.org/_/downloads/en/latest/pdf/"
    },
    include_image_base64=True
)

markdown_pages = [page.markdown for page in ocr_response.pages]
full_md = "\n\n---\n\n".join(markdown_pages)
print(full_md)
with open("full_md.md", "w") as f:
    f.write(full_md)