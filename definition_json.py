import os
import json
import pandas as pd
from openai import AzureOpenAI

# Set up OpenAI Azure environment
client = AzureOpenAI(
    api_key=os.getenv("AZURE_GPT4o_MINI_API_KEY"),
    api_version="2024-02-15-preview",
    azure_endpoint="https://od232800-openai-dev.openai.azure.com/"
)

deployment_name = 'gpt4o-mini'

# Load the JSON data (assumes you have a JSON file with definitions and innovations)
with open("/Users/ter053/PycharmProjects/tacit_innovation/definitions_innovation_output.json", "r") as f:
    data = json.load(f)

# Filter out entries where the definition is "No definition provided"
filtered_data = [entry for entry in data if entry['json_definition']['Definition'] != "No definition provided"]

# Extract the definitions from the JSON data
definitions_list = [entry['json_definition']['Definition'] for entry in filtered_data]

# Collapse all definitions into one big text object
collapsed_definitions = " ".join(definitions_list)

# Prompt for a comprehensive definition
prompt_1 = "You are a scientist conducting a systematic review of the literature on the role of tacit knowledge in innovation. Your goal is to extract key definitions, summarize relevant discussions, and identify major themes across the body of research."
prompt_2 = ("Please review the following definitions of tacit knowledge and synthesize them into a tightly worded, sharp definition that addresses both the cognitive and experiential dimensions. Limit the synthesized definition to one sentence.")

def get_comprehensive_definition(text):
    prompt = f"{prompt_2} [text start] {text} [text end]"
    try:
        response = client.chat.completions.create(
            model=deployment_name,
            messages=[
                {"role": "system", "content": prompt_1},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=300
        )
        return response.choices[0].message.content
    except Exception as e:
        print(f"An error occurred: {e}")
        return "Error in generating comprehensive definition"

# Get the comprehensive definition
comprehensive_definition = get_comprehensive_definition(collapsed_definitions)

# Output the comprehensive definition for verification
print("Comprehensive Definition of Tacit Knowledge:\n")
print(comprehensive_definition)

# Save the comprehensive definition to a text file
output_path = '/Users/ter053/PycharmProjects/tacit_innovation/comprehensive_definition.txt'
with open(output_path, 'w') as f:
    f.write(comprehensive_definition)
