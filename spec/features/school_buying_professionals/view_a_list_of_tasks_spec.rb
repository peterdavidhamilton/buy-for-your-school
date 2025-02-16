require "rails_helper"

feature "Users can view the task list" do
  let(:user) { create(:user) }
  before { user_is_signed_in(user: user) }

  scenario "tasks are grouped by their section" do
    start_journey_from_category(category: "multiple-sections.json")

    within(".app-task-list") do
      expect(page).to have_content("Section A")
      expect(page).to have_content("Section B")
    end

    task_lists = find_all(".app-task-list__items")

    within(task_lists[0]) do
      expect(page).to have_content("Which service do you need?")
    end

    within(task_lists[1]) do
      expect(page).to have_content("Describe what you need")
    end
  end

  scenario "user can navigate back to the task list from a task view" do
    start_journey_with_tasks_from_category(category: "section-with-multiple-tasks.json")

    within(".app-task-list") do
      click_on "Task with multiple steps"
    end

    # Back to the Task page
    click_on(I18n.t("generic.button.back"))

    # Back to the Journey page
    click_on(I18n.t("generic.button.back"))

    expect(page).to have_content(I18n.t("specifying.start_page.page_title"))
  end

  scenario "user can navigate back to the list of journeys from a task list" do
    start_journey_from_category(category: "extended-radio-question.json")

    click_on(I18n.t("generic.button.back"))

    expect(page).to have_content(I18n.t("journey.index.existing.header"))
  end

  scenario "user can navigate back to the dashboard from a step" do
    start_journey_from_category(category: "extended-radio-question.json")

    click_on(I18n.t("generic.button.back"))
    click_on(I18n.t("generic.button.back"))

    expect(page).to have_content(I18n.t("dashboard.header"))
  end

  context "when a task has one step" do
    scenario "user can navigate back to the task list from a step" do
      start_journey_with_tasks_from_category(category: "section-with-single-task.json")

      within(".app-task-list") do
        click_on "Everyday services that are required and need to be considered"
      end

      click_on(I18n.t("generic.button.back"))

      expect(page).to have_content(I18n.t("specifying.start_page.page_title"))
    end
  end

  context "when a task has more than one step" do
    scenario "user can navigate back to the task view from a question" do
      start_journey_with_tasks_from_category(category: "section-with-multiple-tasks.json")

      within(".app-task-list") do
        click_on "Task with multiple steps"
      end

      click_on(I18n.t("generic.button.back"))

      expect(page).to have_content("Task with multiple steps")
    end
  end

  context "when a task includes a step that has been answered" do
    scenario "the task is marked as completed" do
      stub_contentful_category(fixture_filename: "multiple-sections.json")

      answer = create(:short_text_answer, response: "answer")
      journey = answer.step.journey
      journey.update(user: user)

      user_starts_the_journey

      visit journey_path(journey)

      expect(page).to have_content(I18n.t("task_list.status.completed"))
    end

    scenario "shows the section title" do
      start_journey_with_tasks_from_category(category: "section-with-single-task.json")
      within(".app-task-list") do
        expect(page).to have_content("Section with a single task")
      end
    end

    scenario "shows the step title, not the task title" do
      start_journey_with_tasks_from_category(category: "section-with-single-task.json")

      within(".app-task-list") do
        expect(page).to have_content("Everyday services that are required and need to be considered")
        expect(page).to_not have_content("Task with a single step")
      end
    end

    scenario "has a back link on the step page that takes you to the journey page" do
      start_journey_with_tasks_from_category(category: "section-with-single-task.json")

      within(".app-task-list") do
        click_on "Everyday services that are required and need to be considered"
      end

      click_on "Back"

      expect(page).to have_content "Section with a single task"
    end

    scenario "allows the user to complete the step, and returns to the journey page" do
      start_journey_with_tasks_from_category(category: "section-with-single-task.json")

      within(".app-task-list") do
        click_on "Everyday services that are required and need to be considered"
      end

      check "Lunch"
      click_on "Continue"

      expect(page).to have_content "Section with a single task"
      within(".app-task-list") do
        expect(page).to have_content("Complete")
      end
    end
  end

  context "when a task includes an initially HIDDEN step" do
    scenario "should not appear in the task list" do
      start_journey_from_category(category: "hidden-field.json")

      expect(page).not_to have_content("You should NOT be able to see this question")
      expect(page).to have_content("You should be able to see this question")
    end

    scenario "shows the section title" do
      start_journey_with_tasks_from_category(category: "section-with-single-hidden-task.json")
      within(".app-task-list") do
        expect(page).to have_content("Section with a hidden task")
      end
    end

    scenario "does not show the task nor step title" do
      start_journey_with_tasks_from_category(category: "section-with-single-hidden-task.json")

      within(".app-task-list") do
        expect(page).to_not have_content("Task with a hidden step")
      end
    end

    context "when that step becomes visible" do
      it "appears in the order defined in Contentful rather than at the end" do
        start_journey_with_tasks_from_category(category: "show-one-additional-question-in-order.json")

        # Simulate the bug by changing the created_at to a time that incorrectly
        # puts the hidden record at the bottom of the list
        Step.find_by(title: "What support do you have available?").update(created_at: 3.days.ago)
        Step.find_by(title: "What email address did you use?").update(created_at: 2.days.ago)
        Step.find_by(title: "What colour is the sky?").update(created_at: 1.days.ago)

        click_on("One additional question task")
        click_on(I18n.t("generic.button.back"))

        steps = find_all(".govuk-summary-list__row")
        within(".govuk-summary-list") do
          expect(steps[0]).to have_content("What support do you have available?")
          # Hidden field "What colour is the sky?" is correctly omitted at this point
          expect(steps[1]).to have_content("What email address did you use?")
        end

        # Answer the first question to unlock "What colour is the sky?"
        first(".govuk-summary-list__row").click_on(I18n.t("generic.button.change_answer"))
        choose("School expert")
        click_on("Continue")

        # We get taken to the next question so we go back to the task page
        click_on(I18n.t("generic.button.back"))

        # Check that "What colour is in the sky added to the correct place in the list"
        steps = find_all(".govuk-summary-list__row")
        within(".govuk-summary-list") do
          expect(steps[0]).to have_content("What support do you have available?")
          expect(steps[1]).to have_content("What colour is the sky?")
          expect(steps[2]).to have_content("What email address did you use?")
        end
      end
    end
  end

  context "when there is a task with multiple steps" do
    scenario "shows the section title" do
      start_journey_with_tasks_from_category(category: "section-with-multiple-tasks.json")
      within(".app-task-list") do
        expect(page).to have_content("Section with multiple tasks")
      end
    end

    scenario "shows the task titles within the section" do
      start_journey_with_tasks_from_category(category: "section-with-multiple-tasks.json")

      within(".app-task-list") do
        expect(page).to have_content("Task with multiple steps")
      end
    end
  end
end
