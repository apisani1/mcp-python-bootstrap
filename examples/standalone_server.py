#!/usr/bin/env python3
"""
Standalone MCP Prompt Server Example
This version has no external dependencies and can be run directly.
"""

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("My Prompts")


@mcp.prompt()
def write_detailed_historical_report(topic: str, number_of_paragraphs: int = 3) -> str:
    """
    Writes a detailed historical report about a given topic.

    Args:
        topic: The historical topic to write about
        number_of_paragraphs: Number of paragraphs to include (default: 3)
    """
    return f"""Please write a detailed historical report about {topic} with exactly {number_of_paragraphs} paragraphs.

Structure your report as follows:
1. Introduction paragraph providing context and background
2. Main body paragraphs covering key events, figures, and developments
3. Conclusion paragraph summarizing the historical significance

Ensure each paragraph is well-researched and contains specific details, dates, and historical evidence."""


@mcp.prompt()
def analyze_primary_source(source_type: str, time_period: str, region: str) -> str:
    """
    Creates a prompt for analyzing historical primary sources.

    Args:
        source_type: Type of primary source (document, artifact, image, etc.)
        time_period: Historical time period
        region: Geographic region
    """
    return f"""Please analyze this {source_type} from {time_period} in {region}.

Your analysis should cover:

1. **Context and Background**
   - Historical circumstances during {time_period}
   - Significance of {region} during this period
   - Purpose and audience of this {source_type}

2. **Content Analysis**
   - Key themes and messages
   - Language, style, and tone
   - Perspective and potential bias

3. **Historical Significance**
   - What this source reveals about {time_period}
   - How it fits into broader historical narratives
   - Its value for understanding {region}'s history

4. **Limitations and Considerations**
   - What the source doesn't tell us
   - Potential reliability issues
   - Need for corroborating evidence

Please provide specific examples and evidence to support your analysis."""


@mcp.prompt()
def create_timeline(topic: str, start_year: int, end_year: int) -> str:
    """
    Creates a detailed historical timeline for a given topic and time period.

    Args:
        topic: The historical topic for the timeline
        start_year: Starting year for the timeline
        end_year: Ending year for the timeline
    """
    return f"""Create a detailed chronological timeline for {topic} from {start_year} to {end_year}.

Format your timeline as follows:

**{topic} Timeline ({start_year}-{end_year})**

For each significant event, include:
- **Date**: Specific year (and month/day if known)
- **Event**: Brief description of what happened
- **Significance**: Why this event was important
- **Key Figures**: Important people involved
- **Consequences**: Immediate and long-term effects

Focus on:
- Major political developments
- Social and cultural changes
- Economic transformations
- Technological innovations
- Important battles or conflicts (if applicable)

Ensure the timeline is comprehensive and shows the progression and interconnection of events throughout this period."""


if __name__ == "__main__":
    mcp.run()
