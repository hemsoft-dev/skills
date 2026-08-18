document.querySelectorAll("[data-quiz]").forEach((quiz) => {
  const feedback = quiz.querySelector("[data-feedback]");
  const buttons = quiz.querySelectorAll("button[data-answer]");
  const correctMessage = quiz.dataset.feedbackCorrect
    ?? "Correct.";
  const wrongMessage = quiz.dataset.feedbackWrong
    ?? "Try again.";

  buttons.forEach((button) => {
    button.addEventListener("click", () => {
      const correct = button.dataset.correct === "true";

      buttons.forEach((candidate) => {
        candidate.dataset.state = candidate === button
          ? (correct ? "correct" : "wrong")
          : "idle";
      });

      feedback.textContent = correct ? correctMessage : wrongMessage;
    });
  });
});
