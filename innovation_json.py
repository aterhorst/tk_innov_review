import os
import json
from openai import AzureOpenAI

# Set up OpenAI Azure environment
client = AzureOpenAI(
    api_key=os.getenv("AZURE_GPT4o_MINI_API_KEY"),
    api_version="2024-02-15-preview",
    azure_endpoint="https://od232800-openai-dev.openai.azure.com/"
)

deployment_name = 'gpt4o-mini'

# Load the JSON data
with open("/Users/ter053/PycharmProjects/tacit_innovation/definitions_innovation_output.json", "r") as f:
    data = json.load(f)

# Combine the summaries with filenames
combined_texts = [
            f"Filename: {entry.get('file_name', 'Unknown')}\n"
            f"Title: {entry['json_innovation'].get('Title', 'Unknown')}\n"
            f"Authors: {entry['json_innovation'].get('Authors', 'Unknown')}\n"
            f"Publication Year: {entry['json_innovation'].get('Publication Year', 'Unknown')}\n"
            f"Keywords: {', '.join(entry['json_innovation'].get('Keywords', []))}\n"
            f"Main Findings: {'; '.join(entry['json_innovation'].get('Main Findings', []))}\n"
            f"Managerial Implications: {'; '.join(entry['json_innovation'].get('Managerial Implications', []))}\n"
            f"Summary Points: {'; '.join(entry['json_innovation'].get('Summary Points', []))}\n"
            for entry in data
]

# Collapse all combined text into one big text object
collapsed_innovations = " ".join(combined_texts)

# Prompt for synthesizing the role of tacit knowledge in innovation
prompt_1 = "You are a scientist conducting a systematic review of the literature on the role of tacit knowledge in innovation. Your goal is to extract key definitions, summarize relevant discussions, and identify major themes across the body of research."

prompt_2 = (
    "Review the following article summaries and synthesize key insights about the role of tacit knowledge in innovation. "
    "Extract at least 7 conceptually distinct, non-overlapping themes and present each as a JSON object using the following structure:\n\n"
    "{\n"
    '    "Theme": "A clear, descriptive name for the theme.",\n'
    '    "Explanation": "A comprehensive explanation of the theme that includes conceptual foundations, sub-themes, concrete examples, points of divergence, and managerial implications, all presented as a single, coherent paragraph."\n'
    "}\n\n"
    "Instructions\n"
    "1. Extract at least 7 themes, each presented as a flat JSON object following the structure above.\n"
    "2. Each explanation must follow a clear, logical structure that integrates the following components:\n"
    "    - Conceptual Explanation: Provide a clear conceptual overview of the theme and its relevance to tacit knowledge in innovation.\n"
    "    - Sub-Themes: Identify 2-3 sub-themes or sub-dimensions conceptually linked to the broader theme.\n"
    "    - Concrete Examples: Include 3-5 specific examples, case studies, or mechanisms. Examples should span multiple sectors (e.g., construction, health, software) and reference tools, processes, or industry-specific impacts. Cite supporting studies using full author names and publication years (e.g., 'Kucharska and Erickson (2023)').\n"
    "    - Points of Divergence: Highlight disagreements, contradictions, or unresolved tensions related to the theme. Indicate which articles present opposing perspectives and provide context for the disagreement (e.g., differences in industry, sector, or research methods).\n"
    "    - Managerial Implications: Provide actionable, specific recommendations for managers, practitioners, or policymakers. Recommendations should be clear and grounded in insights from this theme. Avoid vague advice like 'foster knowledge sharing.'\n"
    "3. Explanations, examples, and discussions must be factual and evidence-based with clear references to relevant articles (e.g., 'John Doe (2004)'). Avoid speculative language (e.g., 'it is possible') or ambiguous phrases (e.g., 'studies suggest').\n"
    "4. Cite each referenced article using the full author names and publication years (e.g., 'Kucharska and Erickson (2023) emphasize that...').\n\n"
    "Now, extract the themes using the structure and guidelines above."
)






def synthesize_innovation(text):
    """Sends the text to the API and returns parsed JSON output."""
    prompt = f"{prompt_2} [text start] {text} [text end]"
    try:
        response = client.chat.completions.create(
            model=deployment_name,
            messages=[
                {"role": "system", "content": prompt_1},
                {"role": "user", "content": prompt}
            ],
            temperature=0,
            max_tokens=10000,
            response_format={"type": "json_object"}
        )
        raw_content = response.choices[0].message.content

        if not raw_content:
            print("Error: Empty response content from OpenAI API")
            return {"Error": "Empty response content from OpenAI API"}

        print("Raw response from OpenAI API (first 1000 characters):\n", raw_content[:1000])  # Debugging
        result = json.loads(raw_content)
        return result
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {e}. Raw content: {raw_content[:1000]}")
        return {"Error": "Invalid JSON response from OpenAI API"}
    except Exception as e:
        print(f"An error occurred: {e}")
        return {"Error": "Error in generating synthesis"}


# Synthesize innovation from combined text
synthesized_innovation = synthesize_innovation(collapsed_innovations)

# Save the synthesis to a JSON file
output_path = '/Users/ter053/PycharmProjects/tacit_innovation/synthesized_innovation_with_titles_and_authors.json'
with open(output_path, 'w') as f:
    json.dump(synthesized_innovation, f, indent=4)
