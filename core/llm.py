from langchain_ollama.llms import OllamaLLM
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage
from .config import get_settings
settings = get_settings()

class LLM:
    def __init__(self):
        self.system_message = (
            "You are an expert Scenic DSL assistant.\n"
            "Your task is to read the provided documentation chunks and generate executable DSL code that satisfies the user's request.\n"
            "Provide the full DSL code, which should be a valid Scenic DSL code and can be executed directly. Output only a Scenic program in one fenced code block. No prose.\n"
            "Do not invent functions or syntax that are not supported by the DSL indicated in the evidence.\n"
            "Few-shot exemplars:\n"
            "Question: Parking car pulling out (interaction + angles)\n"
            "Answer:\n"
            "```scenic\n"
            "param map = localPath('../../assets/maps/CARLA/Town05.xodr')\n"
            "param carla_map = 'Town05'\n"
            "param time_step = 1.0/10\n"
            "model scenic.domains.driving.model\n"
            "behavior PullIntoRoad():\n"
            "    while (distance from self to ego) > 15:\n"
            "        wait\n"
            "    do FollowLaneBehavior(laneToFollow=ego.lane)\n"
            "ego = new Car with behavior DriveAvoidingCollisions(avoidance_threshold=5)\n"
            "rightCurb = ego.laneGroup.curb\n"
            "spot = new OrientedPoint on visible rightCurb\n"
            "badAngle = Uniform(-1.0, 1.0) * Range(10, 20) deg\n"
            "parkedCar = new Car left of spot by 0.5,\n"
            "                facing badAngle relative to roadDirection,\n"
            "                with behavior PullIntoRoad\n"
            "require (distance to parkedCar) > 20\n"
            "monitor StopAfterInteraction():\n"
            "    for i in range(50):\n"
            "        wait\n"
            "    while ego.speed > 2:\n"
            "        wait\n"
            "    for i in range(50):\n"
            "        wait\n"
            "    terminate\n"
            "```"
        )

        from langchain_core.prompts import MessagesPlaceholder
        self.prompt = ChatPromptTemplate.from_messages([
            SystemMessage(content=self.system_message),
            MessagesPlaceholder(variable_name="messages"),
        ])
        print(f"Using LLM provider: {getattr(settings, 'LLM_PROVIDER', 'ollama')}")

        provider = getattr(settings, 'LLM_PROVIDER', 'ollama').lower()
        if provider == "openai":
            print(f"Using OpenAI LLM: {settings.OPENAI_MODEL_NAME}")
            self.model = ChatOpenAI(
                model=settings.OPENAI_MODEL_NAME,
                api_key=settings.OPENAI_API_KEY,
                temperature=settings.LLM_TEMPERATURE,
                max_tokens=settings.LLM_MAX_TOKENS,
                top_p=settings.LLM_TOP_P,
            )
        else:
            print(f"Using Ollama LLM: {settings.LLM_MODEL_NAME}")
            # Initialize Ollama with parameters for longer, more detailed responses
            self.model = OllamaLLM(
                model=settings.LLM_MODEL_NAME,
                base_url=settings.OLLAMA_URL,
                temperature=settings.LLM_TEMPERATURE,
                num_predict=settings.LLM_MAX_TOKENS,
                top_p=settings.LLM_TOP_P,
                top_k=settings.LLM_TOP_K
            )
        self.chain = self.prompt | self.model

    def generate_response(self, context: str, question: str, system_prompt: str = None) -> str:
        if not context.strip():
            context = "[NO CONTEXT AVAILABLE]"
        print("Context:", context)
        response = self.chain.invoke({"context": context, "question": question, "system_prompt": system_prompt})
        return response.content if hasattr(response, 'content') else str(response)
    

