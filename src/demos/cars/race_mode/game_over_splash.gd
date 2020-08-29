extends Control

"""Simple game-over screen that is displayed when the first car finishes all laps
or the player crashes.
"""

signal restart_race

var race_completed_text = """%s was the first driver to complete
%s laps around the track.
Retry or go back to demo selection?
"""

var game_over_text = "You crashed. Try again, or return to demo selection?"

func initialize(winner: String, num_laps: int, player_crashed: bool) -> void:
    """Display a text based on whether the player crashed or the race has been finished.
    """
    if player_crashed:
        $InfoText.text = game_over_text
    else:
        $InfoText.text = race_completed_text % [winner, num_laps]
    

func _on_GoBack_pressed() -> void:
    """Return to demo chooser scene
    """
    get_tree().change_scene("res://demos/demo_loader/DemoLoader.tscn")


func _on_Retry_pressed() -> void:
    emit_signal("restart_race")
