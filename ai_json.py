import os
import pandas as pd
import json
from openai import AzureOpenAI

# Set up OpenAI Azure environment
client = AzureOpenAI(
    api_key=os.getenv("AZURE_GPT4o_MINI_API_KEY"),
    api_version="2024-02-15-preview",
    azure_endpoint="https://od232800-openai-dev.openai.azure.com/"
)

deployment_name = 'gpt4o-mini'

# Load the PDF texts
pdf_texts = pd.read_csv("/Users/ter053/PycharmProjects/tacit_innovation/pdf_texts.csv")

# Define prompts
prompt_1 = (
    "You are a scientist conducting a systematic review of the literature on the role of tacit knowledge in innovation. "
    "Your goal is to extract key definitions, summarize relevant discussions, and identify major themes across the body of research."
)

prompt_2 = (
    "Extract a formal definition of tacit knowledge from the following text and store it as a JSON object using the format below.\n\n"
    "JSON Structure\n"
    "{\n"
    '    "Title": "Title of the article",\n'
    '    "Authors": "Full names of all authors, separated by commas. Do not use et al.",\n'
    '    "Publication Year": "Year the article was published",\n'
    '    "Definition": "The formal definition of tacit knowledge as stated in the text.",\n'
    '    "Source of definition": "The source cited for the definition (e.g., author names and year) or \'No source.\'"\n'
    "}\n\n"
    "Instructions\n"
    "1. Follow the JSON structure provided above. All fields must be completed using information from the text.\n"
    "2. Extract the definition of tacit knowledge exactly as stated in the text. Do not summarize, rephrase, or infer meaning.\n"
    "3. If a source is cited for the definition, provide the author names and year (e.g., 'Hau and Evangelista (2007)'). If no source is cited, state 'No source.'\n"
    "4. If no definition of tacit knowledge is present in the text, return 'No definition provided.'\n\n"
    "Now, extract the definition of tacit knowledge from the following text using the structure and guidelines above."
)


prompt_3 = (
    "Read the following research article and provide a comprehensive structured summary of its key insights as a JSON object using the format below.\n\n"
    "JSON Structure\n"
    "{\n"
    '    "Title": "Title of the article",\n'
    '    "Authors": "Full names of all authors, separated by commas. Do not use et al.",\n'
    '    "Publication Year": "Year the article was published",\n'
    '    "Keywords": ["Keyword 1", "Keyword 2", "Keyword 3", "Keyword 4", "Keyword 5"],\n'
    '    "Main Findings": [\n'
    '        "10 evidence-based findings reflecting empirical results, theoretical contributions, or key insights from the study.",\n'
    '        "Summarize conceptual models, frameworks, or processes, if applicable."\n'
    '    ],\n'
    '    "Managerial Implications": [\n'
    '        "3-5 actionable insights for managers, practitioners, or policymakers.",\n'
    '        "If no practical implications are mentioned, state explicitly: \'No practical implications discussed.\'"\n'
    '    ],\n'
    '    "Methodology": "Summary of the research design, sample, data collection, and analysis approach."\n'
    "}\n\n"
    "Instructions\n"
    "1. Follow the JSON structure provided above. All fields must be completed using information from the article.\n"
    "2. If the Title, Authors, or Publication Year is missing, set the field as 'Unknown'.\n"
    "3. List the full names of all authors in the 'Authors' field. Do not use 'et al.'\n"
    "4. Avoid speculative language or assumptions. Summarize only factual, evidence-based insights from the article.\n"
    "5. For Methodology, describe the research design, sample, data collection, and analysis approach in a clear, concise sentence.\n\n"
    "Now, summarize the following research article using the structure and guidelines above."
)





# Function to get GPT-4 definition and format as JSON
def get_definition(text):
    prompt = f"{prompt_2} [text start] {text} [text end]"
    try:
        response = client.chat.completions.create(
            model=deployment_name,
            messages=[
                {"role": "system", "content": prompt_1},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=1000,
            response_format={"type": "json_object"}
        )
        return json.loads(response.choices[0].message.content)
    except Exception as e:
        print(f"An error occurred: {e}")
        return {
            "Title": "Unknown",
            "Authors": "Unknown",
            "Publication Date": "Unknown",
            "Definition": "No definition provided",
            "Source of definition": "No source"
        }

# Function to get GPT-4 response for innovation and format as JSON
def get_innovation_with_few_shot(text):
    prompt = f"{prompt_3} [text start] {text} [text end]"
    try:
        response = client.chat.completions.create(
            model=deployment_name,
            messages=[
                {"role": "system", "content": prompt_1},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=1000,
            response_format={"type": "json_object"}
        )
        return json.loads(response.choices[0].message.content)
    except Exception as e:
        print(f"An error occurred: {e}")
        return {
            "Title": "Unknown",
            "Authors": "Unknown",
            "Publication Date": "Unknown",
            "Key Points": ["Error in generating innovation statement"]
        }

# Apply the GPT-4 model to extract definitions and innovation summaries
pdf_texts['json_definition'] = pdf_texts['text'].apply(get_definition)
pdf_texts['json_innovation'] = pdf_texts['text'].apply(get_innovation_with_few_shot)

# Drop the 'text' column
pdf_texts = pdf_texts.drop(columns=['text'])

# Convert the DataFrame to a list of dictionaries
json_output = pdf_texts[['file_name', 'json_definition', 'json_innovation']].to_dict(orient='records')

# Save the JSON output to a file
output_path = '/Users/ter053/PycharmProjects/tacit_innovation/definitions_innovation_output.json'
with open(output_path, 'w') as f:
    json.dump(json_output, f, indent=4)

# Output the JSON for verification
print(json.dumps(json_output, indent=4))