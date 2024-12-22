import os
from pdfminer.high_level import extract_text
import pandas as pd

# Function to read a PDF file and return its text
def read_pdf(file_path):
    try:
        text = extract_text(file_path)
        return text.strip()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return None

# Folder containing PDFs
folder_path = '/Users/ter053/OneDrive - CSIRO/Projects/openalex/pdfs'

# List to hold PDF data
pdf_data = []

# Iterate over all PDF files in the folder
for file_name in os.listdir(folder_path):
    if file_name.endswith('.pdf'):
        file_path = os.path.join(folder_path, file_name)
        print(f"Reading file: {file_name}")
        text = read_pdf(file_path)
        if text:  # Only add to list if text extraction is successful
            pdf_data.append({'file_name': file_name, 'text': text})

# Convert the list to a DataFrame
df = pd.DataFrame(pdf_data)

# Display the DataFrame
print(df)

# Optionally, save the DataFrame to a CSV file
df.to_csv('pdf_texts.csv', index=False)