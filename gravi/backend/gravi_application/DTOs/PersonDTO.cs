using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Diagnostics.Metrics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace gravi_application.DTOs
{
    public class PersonDTO
    {
        public enum GenderType { NotProvided = 0, Male = 1, Female = 2 };
        public long? PersonId { get; set; }
        [Length(2, 50, ErrorMessage = "First name need to be between 2 and 50 characters.")]
        public required string FirstName { get; set; }
        public string? MiddleName { get; set; } = string.Empty;

        [Length(2, 50, ErrorMessage = "Last name need to be between 2 and 50 characters.")]
        public required string LastName { get; set; }
        public required CountryDTO Country { get; set; }
        public required DateTime DateOfBirth { get; set; }
        public required GenderType Gender { get; set; }
    }
}
