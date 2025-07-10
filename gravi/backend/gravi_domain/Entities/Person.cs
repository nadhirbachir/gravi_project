using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_domain.Entities
{
    public class Person
    {
        public long? PersonId { get; set; }

        [MaxLength(50, ErrorMessage = "Max first name length is 50 characters only.")]
        public required string FirstName { get; set; }

        [MaxLength(50, ErrorMessage = "Max middle name length is 50 characters only.")]
        public string? MiddleName { get; set; } = string.Empty;

        [MaxLength(50, ErrorMessage = "Max last name length is 50 characters only.")]
        public required string LastName { get; set; }
        public required Country Country { get; set; }
        public required DateTime DateOfBirth { get; set; }
        public required short Gender { get; set; }
    }
}
