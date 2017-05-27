import GRDB

class Person: Record {
    var id: Int64?
    var name: String
    var score: Int
    
    init(name: String, score: Int) {
        self.name = name
        self.score = score
        super.init()
    }
    
    // MARK: Record overrides
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    required init(row: Row) {
        id = row["id"]
        name = row["name"]
        score = row["score"]
        super.init(row: row)
    }
    
    override var persistentDictionary: [String : DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "score": score]
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
    
    // MARK: Random
    
    private static let names = ["Arthur", "Anita", "Barbara", "Bernard", "Craig", "Chiara", "David", "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette", "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl", "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nicole", "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul", "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain", "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann", "Zazie", "Zoé"]
    
    class func randomName() -> String {
        return names[Int(arc4random_uniform(UInt32(names.count)))]
    }
    
    class func randomScore() -> Int {
        return 10 * Int(arc4random_uniform(101))
    }

}
