/// Type de meuble d'un obstacle fixe de chambre. Influence son rendu, et pour
/// certains types, son comportement physique :
/// - [bed] fait rebondir la bille (voir Ruler.restitution)
/// - [wardrobe] est pensé pour être posé presque à la verticale, pour agir
///   comme un mur qu'il faut contourner plutôt qu'une plateforme
/// Les autres types ([plank], [chair], [table]) ont un comportement standard
/// et ne se distinguent que visuellement.
enum FurnitureType {
  plank,
  chair,
  table,
  bed,
  wardrobe,
}
