import sys

from core.graph import build_app


def main():
    app = build_app()

    print("Please describe the scenario: ")

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("Bye")
            break

        if not user_input:
            continue

        if user_input.lower() == "/exit":
            print("Bye")
            break

        state = {"question": user_input}

        result = app.invoke(state)
        answer = result.get("answer", "No answer generated.")
        print(f"Assistant: {answer}\n")


if __name__ == "__main__":
    main()
